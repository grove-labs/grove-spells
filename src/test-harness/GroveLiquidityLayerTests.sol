// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "grove-address-registry/Avalanche.sol";
import { Ethereum }  from "grove-address-registry/Ethereum.sol";

import { IALMProxy }         from "grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { ChainId, ChainIdUtils } from "../libraries/ChainId.sol";

import { SpellRunner } from "./SpellRunner.sol";

struct GroveLiquidityLayerContext {
    address     controller;
    IALMProxy   proxy;
    IRateLimits rateLimits;
    address     relayer;
    address     freezer;
}

struct CentrifugeConfig {
    address centrifugeRoot;
    address centrifugeInvestmentManager;
    bytes16 centrifugeTrancheId;
    uint64  centrifugePoolId;
    uint128 centrifugeAssetId;
}

interface IInvestmentManager {
    function fulfillCancelDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 fulfillment
    ) external;
    function fulfillCancelRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 shares
    ) external;
    function fulfillDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
    function fulfillRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
    function poolManager() external view returns (address);
}

interface IPoolManager {
    function assetToId(address asset) external view returns (uint128);
}

interface ICentrifugeVault {
    function asset()     external view returns (address);
    function manager()   external view returns (address);
    function root()      external view returns (address);
    function share()     external view returns (address);
    function trancheId() external view returns (bytes16);
    function poolId()    external view returns (uint64);
}

struct CentrifugeV3Config {
    address centrifugeVault;
    address centrifugeRoot;
    address centrifugeManager;
    bytes16 centrifugeScId;
    uint64  centrifugePoolId;
    uint128 centrifugeAssetId;
}

interface ICentrifugeV3Vault {
    function asset()   external view returns (address);
    function share()   external view returns (address);
    function manager() external view returns (address);
    function poolId()  external view returns (uint64);
    function scId()    external view returns (bytes16);
    function root()    external view returns (address);
}

interface ICentrifugeV3ShareLike is IERC20 {
    function hook() external view returns (address);
}

interface IFreelyTransferableHookLike {
    function updateMember(address token, address user, uint64 validUntil) external;
}

interface IAsyncRedeemManagerLike {
    function issuedShares(
        uint64  poolId,
        bytes16 scId,
        uint128 shareAmount,
        uint128 pricePoolPerShare) external;
    function revokedShares(
        uint64  poolId,
        bytes16 scId,
        uint128 assetId,
        uint128 assetAmount,
        uint128 shareAmount,
        uint128 pricePoolPerShare) external;
    function fulfillDepositRequest(
        uint64  poolId,
        bytes16 scId,
        address user,
        uint128 assetId,
        uint128 fulfilledAssets,
        uint128 fulfilledShares,
        uint128 cancelledAssets
    ) external;
    function fulfillRedeemRequest(
        uint64  poolId,
        bytes16 scId,
        address user,
        uint128 assetId,
        uint128 fulfilledAssets,
        uint128 fulfilledShares,
        uint128 cancelledShares
    ) external;
    function balanceSheet()            external view returns (address);
    function spoke()                   external view returns (address);
    function poolEscrow(uint64 poolId) external view returns (address);
}

interface IBalanceSheetLike {
    function deposit(uint64 poolId, bytes16 scId, address asset, uint256 tokenId, uint128 amount)
        external;
}

interface ISpokeLike {
    function assetToId(address asset, uint256 tokenId) external view returns (uint128);
}

abstract contract GroveLiquidityLayerTests is SpellRunner {

    function _getGroveLiquidityLayerContext(ChainId chain) internal pure returns(GroveLiquidityLayerContext memory ctx) {
        if (chain == ChainIdUtils.Ethereum()) {
            ctx = GroveLiquidityLayerContext(
                Ethereum.ALM_CONTROLLER,
                IALMProxy(Ethereum.ALM_PROXY),
                IRateLimits(Ethereum.ALM_RATE_LIMITS),
                Ethereum.ALM_RELAYER,
                Ethereum.ALM_FREEZER
        );
        } else if (chain == ChainIdUtils.Avalanche()) {
            ctx = GroveLiquidityLayerContext(
                Avalanche.ALM_CONTROLLER,
                IALMProxy(Avalanche.ALM_PROXY),
                IRateLimits(Avalanche.ALM_RATE_LIMITS),
                Avalanche.ALM_RELAYER,
                Avalanche.ALM_FREEZER
            );
        } else {
            revert("Chain not supported by GroveLiquidityLayerTests context");
        }
    }

    function _getGroveLiquidityLayerContext() internal view returns(GroveLiquidityLayerContext memory) {
        return _getGroveLiquidityLayerContext(ChainIdUtils.fromUint(block.chainid));
    }

   function _assertRateLimit(
       bytes32 key,
       uint256 maxAmount,
       uint256 slope
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getGroveLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, maxAmount);
        assertEq(rateLimit.slope,     slope);
    }

   function _assertUnlimitedRateLimit(
       bytes32 key
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getGroveLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, type(uint256).max);
        assertEq(rateLimit.slope,     0);
    }

   function _assertRateLimit(
       bytes32 key,
       uint256 maxAmount,
       uint256 slope,
       uint256 lastAmount,
       uint256 lastUpdated
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getGroveLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  lastAmount);
        assertEq(rateLimit.lastUpdated, lastUpdated);
    }

    function _testERC4626Onboarding(
        address vault,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        bool unlimitedDeposit = depositMax == type(uint256).max;

        // Note: ERC4626 signature is the same for mainnet and foreign
        deal(IERC4626(vault).asset(), address(ctx.proxy), expectedDepositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_4626_DEPOSIT(),
            vault
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_4626_WITHDRAW(),
            vault
        );

        _assertRateLimit(depositKey, 0, 0);
        _assertRateLimit(withdrawKey, 0, 0);

        // TODO: Uncomment this once the relayer going to be properly set before the payload execution
        // vm.prank(ctx.relayer);
        // vm.expectRevert("RateLimits/zero-maxAmount");
        // MainnetController(ctx.controller).depositERC4626(vault, expectedDepositAmount);

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, depositMax, depositSlope);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        if (!unlimitedDeposit) {
            vm.prank(ctx.relayer);
            vm.expectRevert("RateLimits/rate-limit-exceeded");
            MainnetController(ctx.controller).depositERC4626(vault, depositMax + 1);
        }

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  depositMax);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).depositERC4626(vault, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).withdrawERC4626(vault, expectedDepositAmount / 2);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        if (!unlimitedDeposit) {
            // Do some sanity checks on the slope
            // This is to catch things like forgetting to divide to a per-second time, etc

            // We assume it takes at least 1 day to recharge to max
            uint256 dailySlope = depositSlope * 1 days;
            assertLe(dailySlope, depositMax);

            // It shouldn"t take more than 30 days to recharge to max
            uint256 monthlySlope = depositSlope * 30 days;
            assertGe(monthlySlope, depositMax);
        }
    }

    function _testCentrifugeV3Onboarding(
        address centrifugeVaultAddress,
        address usdcAddress,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) public {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        ICentrifugeV3Vault centrifugeVault = ICentrifugeV3Vault(centrifugeVaultAddress);
        IAsyncRedeemManagerLike centrifugeManager = IAsyncRedeemManagerLike(centrifugeVault.manager());
        ISpokeLike centrifugeSpoke = ISpokeLike(centrifugeManager.spoke());

        CentrifugeV3Config memory centrifugeConfig = CentrifugeV3Config({
            centrifugeVault: centrifugeVaultAddress,
            centrifugeRoot: centrifugeVault.root(),
            centrifugeManager: address(centrifugeManager),
            centrifugeScId: centrifugeVault.scId(),
            centrifugePoolId: centrifugeVault.poolId(),
            centrifugeAssetId: centrifugeSpoke.assetToId(centrifugeVault.asset(), 0)
        });

        // TODO: Remove this once the Centrifuge fully migrates to V3, setting a new root address on Mainnet
        if (ChainIdUtils.fromUint(block.chainid) == ChainIdUtils.Ethereum()) {
            centrifugeConfig.centrifugeRoot = address(0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);
        }

        ICentrifugeV3ShareLike vaultToken = ICentrifugeV3ShareLike(centrifugeVault.share());

        vm.startPrank(centrifugeConfig.centrifugeRoot);
        IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(ctx.proxy), type(uint64).max);
        vm.stopPrank();

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_7540_DEPOSIT(),
            centrifugeVaultAddress
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_7540_REDEEM(),
            centrifugeVaultAddress
        );

        _assertRateLimit(depositKey, 0, 0);
        _assertRateLimit(redeemKey,  0, 0);

        executeAllPayloadsAndBridges();

        deal(centrifugeVault.asset(), address(ctx.proxy), expectedDepositAmount);

        _assertRateLimit(depositKey, depositMax,        depositSlope);
        _assertRateLimit(redeemKey,  type(uint256).max, 0);

        IERC20 usdc = IERC20(usdcAddress);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       expectedDepositAmount);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeVaultAddress, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax - expectedDepositAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        _centrifugeV3FulfillDepositRequest(
            centrifugeConfig,
            expectedDepositAmount
        );

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeVaultAddress);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), expectedDepositAmount / 2);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestRedeemERC7540(centrifugeVaultAddress, expectedDepositAmount / 2);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        _centrifugeV3FulfillRedeemRequest(
            centrifugeConfig,
            expectedDepositAmount / 2
        );

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimRedeemERC7540(centrifugeVaultAddress);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  expectedDepositAmount);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);
    }

    function _centrifugeV3FulfillDepositRequest(
        CentrifugeV3Config memory config,
        uint256 assetAmount
    ) internal {
        uint128 _assetAmount = uint128(assetAmount);
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();


        vm.prank(config.centrifugeRoot);
        IAsyncRedeemManagerLike(config.centrifugeManager).issuedShares(
            config.centrifugePoolId,
            config.centrifugeScId,
            _assetAmount / 2,
            2e18
        );

        // Fulfill request at price 2.0
        vm.prank(config.centrifugeRoot);
        IAsyncRedeemManagerLike(config.centrifugeManager).fulfillDepositRequest(
            config.centrifugePoolId,
            config.centrifugeScId,
            address(ctx.proxy),
            config.centrifugeAssetId,
            _assetAmount,
            _assetAmount / 2,
            0
        );
    }

    function _centrifugeV3FulfillRedeemRequest(
        CentrifugeV3Config memory config,
        uint256 tokenAmount
    ) internal {
        uint128 _tokenAmount = uint128(tokenAmount);
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        address poolEscrow = IAsyncRedeemManagerLike(config.centrifugeManager).poolEscrow(config.centrifugePoolId);
        deal(ICentrifugeV3Vault(config.centrifugeVault).asset(), poolEscrow, 5_000_000_000e6);

       // Deposit assets into balanceSheet
        deal(ICentrifugeV3Vault(config.centrifugeVault).asset(), config.centrifugeRoot, tokenAmount * 2);
        IBalanceSheetLike balanceSheet = IBalanceSheetLike(IAsyncRedeemManagerLike(config.centrifugeManager).balanceSheet());
        vm.startPrank(config.centrifugeRoot);
        IERC20(ICentrifugeV3Vault(config.centrifugeVault).asset()).approve(address(balanceSheet), tokenAmount * 2);
        balanceSheet.deposit(config.centrifugePoolId, config.centrifugeScId, ICentrifugeV3Vault(config.centrifugeVault).asset(), 0, uint128(tokenAmount * 2));
        vm.stopPrank();

        // Revoke shares
        vm.prank(config.centrifugeRoot);
        IAsyncRedeemManagerLike(config.centrifugeManager).revokedShares(
            config.centrifugePoolId,
            config.centrifugeScId,
            config.centrifugeAssetId,
            _tokenAmount * 2,
            _tokenAmount,
            2e18
        );

        // Fulfill request at price 2.0
        vm.prank(config.centrifugeRoot);
        IAsyncRedeemManagerLike(config.centrifugeManager).fulfillRedeemRequest(
            config.centrifugePoolId,
            config.centrifugeScId,
            address(ctx.proxy),
            config.centrifugeAssetId,
            _tokenAmount * 2,
            _tokenAmount,
            0
        );
    }

    function _testCentrifugeOnboarding(
        address centrifugeVault,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) public {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        address centrifugeInvestmentManager = ICentrifugeVault(centrifugeVault).manager();
        CentrifugeConfig memory centrifugeConfig = CentrifugeConfig({
            centrifugeRoot: ICentrifugeVault(centrifugeVault).root(),
            centrifugeInvestmentManager: centrifugeInvestmentManager,
            centrifugeTrancheId: ICentrifugeVault(centrifugeVault).trancheId(),
            centrifugeAssetId: IPoolManager(IInvestmentManager(centrifugeInvestmentManager).poolManager()).assetToId(ICentrifugeVault(centrifugeVault).asset()),
            centrifugePoolId: ICentrifugeVault(centrifugeVault).poolId()
        });


        deal(IERC4626(centrifugeVault).asset(), address(ctx.proxy), expectedDepositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_7540_DEPOSIT(),
            centrifugeVault
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_7540_REDEEM(),
            centrifugeVault
        );

        _assertRateLimit(depositKey,  0, 0);
        _assertRateLimit(redeemKey,   0, 0);

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, depositMax,        depositSlope);
        _assertRateLimit(redeemKey,  type(uint256).max, 0);

        IERC20 usdc       = IERC20(Ethereum.USDC);
        IERC20 vaultToken = IERC20(ICentrifugeVault(centrifugeVault).share());

        assertEq(usdc.balanceOf(address(ctx.proxy)),       expectedDepositAmount);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeVault, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax - expectedDepositAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        _centrifugeFulfillDepositRequest(
            centrifugeConfig,
            expectedDepositAmount
        );

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeVault);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), expectedDepositAmount / 2);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestRedeemERC7540(centrifugeVault, expectedDepositAmount / 2);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        _centrifugeFulfillRedeemRequest(
            centrifugeConfig,
            expectedDepositAmount / 2
        );

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimRedeemERC7540(centrifugeVault);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  expectedDepositAmount);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);
    }

    function _centrifugeFulfillDepositRequest(
        CentrifugeConfig memory config,
        uint256 assetAmount
    ) internal {
        uint128 _assetAmount = uint128(assetAmount);
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        // Fulfill request at price 2.0
        vm.prank(config.centrifugeRoot);
        IInvestmentManager(config.centrifugeInvestmentManager).fulfillDepositRequest(
            config.centrifugePoolId,
            config.centrifugeTrancheId,
            address(ctx.proxy),
            config.centrifugeAssetId,
            _assetAmount,
            _assetAmount / 2
        );
    }

    function _centrifugeFulfillRedeemRequest(
        CentrifugeConfig memory config,
        uint256 tokenAmount
    ) internal {
        uint128 _tokenAmount = uint128(tokenAmount);
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        // Fulfill request at price 2.0
        vm.prank(config.centrifugeRoot);
        IInvestmentManager(config.centrifugeInvestmentManager).fulfillRedeemRequest(
            config.centrifugePoolId,
            config.centrifugeTrancheId,
            address(ctx.proxy),
            config.centrifugeAssetId,
            _tokenAmount * 2,
            _tokenAmount
        );
    }

    function _testControllerUpgrade(address oldController, address newController) internal {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        // Note the functions used are interchangable with mainnet and foreign controllers
        MainnetController controller = MainnetController(newController);

        bytes32 CONTROLLER = ctx.proxy.CONTROLLER();
        bytes32 RELAYER    = controller.RELAYER();
        bytes32 FREEZER    = controller.FREEZER();

        assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), true);
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), false);

        assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), true);
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), false);

        assertEq(controller.hasRole(RELAYER, ctx.relayer),        false);
        assertEq(controller.hasRole(FREEZER, ctx.freezer),        false);

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE), bytes32(uint256(uint160(address(0)))));
        } else {
            assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),  bytes32(uint256(uint160(address(0)))));
        }

        executeAllPayloadsAndBridges();

        assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), false);
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), true);

        assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), false);
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), true);

        assertEq(controller.hasRole(RELAYER, ctx.relayer),        true);
        assertEq(controller.hasRole(FREEZER, ctx.freezer),        true);

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE), bytes32(uint256(uint160(Avalanche.ALM_PROXY))));
        } else {
            assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),  bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
        }
    }
}
