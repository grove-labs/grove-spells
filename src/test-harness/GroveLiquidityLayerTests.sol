// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "grove-address-registry/Avalanche.sol";
import { Ethereum }  from "grove-address-registry/Ethereum.sol";
import { Plume }     from "grove-address-registry/Plume.sol";

import { IALMProxy }         from "grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { CastingHelpers }             from "src/libraries/CastingHelpers.sol";
import { ChainId, ChainIdUtils }      from "src/libraries/ChainId.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/GroveLiquidityLayerHelpers.sol";

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
    address centrifugeAsset;
    address centrifugeSpoke;
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
    function file(bytes32 what, address data) external;
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
    function updatePricePoolPerAsset(uint64 poolId, bytes16 scId, uint128 assetId, uint128 price, uint64 computedAt) external;
    event InitiateTransferShares(
        uint16 centrifugeId,
        uint64 indexed poolId,
        bytes16 indexed scId,
        address indexed sender,
        bytes32 destinationAddress,
        uint128 amount
    );
}

abstract contract GroveLiquidityLayerTests is SpellRunner {

    function _getGroveLiquidityLayerContext(ChainId chain) internal view returns(GroveLiquidityLayerContext memory ctx) {
        address controller;
        if(chainData[chain].spellExecuted) {
            controller = chainData[chain].newController;
        } else {
            controller = chainData[chain].prevController;
        }
        if (chain == ChainIdUtils.Ethereum()) {
            ctx = GroveLiquidityLayerContext(
                controller,
                IALMProxy(Ethereum.ALM_PROXY),
                IRateLimits(Ethereum.ALM_RATE_LIMITS),
                Ethereum.ALM_RELAYER,
                Ethereum.ALM_FREEZER
        );
        } else if (chain == ChainIdUtils.Avalanche()) {
            ctx = GroveLiquidityLayerContext(
                controller,
                IALMProxy(Avalanche.ALM_PROXY),
                IRateLimits(Avalanche.ALM_RATE_LIMITS),
                Avalanche.ALM_RELAYER,
                Avalanche.ALM_FREEZER
            );
        } else if (chain == ChainIdUtils.Plume()) {
            ctx = GroveLiquidityLayerContext(
                controller,
                IALMProxy(Plume.ALM_PROXY),
                IRateLimits(Plume.ALM_RATE_LIMITS),
                Plume.ALM_RELAYER,
                Plume.ALM_FREEZER
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

    function _assertZeroRateLimit(
        bytes32 key
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getGroveLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, 0);
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
            GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            vault
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_WITHDRAW,
            vault
        );

        _assertZeroRateLimit(depositKey);
        _assertZeroRateLimit(withdrawKey);

        vm.prank(ctx.relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        MainnetController(ctx.controller).depositERC4626(vault, expectedDepositAmount);

        executeAllPayloadsAndBridges();

        // Reload the context after spell execution to get the new controller after potential controller upgrade
        ctx = _getGroveLiquidityLayerContext();

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
        address centrifugeVault,
        address usdcAddress,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) public {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        CentrifugeV3Config memory centrifugeConfig = _prepareCentrifugeConfig(centrifugeVault);

        ICentrifugeV3ShareLike vaultToken = ICentrifugeV3ShareLike(ICentrifugeV3Vault(centrifugeVault).share());

        _prepareCentrifugeWhitelisting(vaultToken, centrifugeConfig.centrifugeRoot);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_7540_DEPOSIT,
            centrifugeVault
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_7540_REDEEM,
            centrifugeVault
        );

        _assertZeroRateLimit(depositKey);
        _assertZeroRateLimit(redeemKey);

        executeAllPayloadsAndBridges();

        // Reload the context after spell execution to get the new controller after potential controller upgrade
        ctx = _getGroveLiquidityLayerContext();

        deal(ICentrifugeV3Vault(centrifugeVault).asset(), address(ctx.proxy), expectedDepositAmount);

        _assertRateLimit(depositKey, depositMax,        depositSlope);
        _assertRateLimit(redeemKey,  type(uint256).max, 0);

        IERC20 usdc = IERC20(usdcAddress);

        uint256 startShareBalance = vaultToken.balanceOf(address(ctx.proxy));

        assertEq(usdc.balanceOf(address(ctx.proxy)),       expectedDepositAmount);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeVault, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax - expectedDepositAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        _centrifugeV3FulfillDepositRequest(
            centrifugeConfig,
            expectedDepositAmount
        );

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeVault);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance + expectedDepositAmount / 2);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestRedeemERC7540(centrifugeVault, expectedDepositAmount / 2);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        _centrifugeV3FulfillRedeemRequest(
            centrifugeConfig,
            expectedDepositAmount / 2
        );

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimRedeemERC7540(centrifugeVault);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  expectedDepositAmount);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);
    }


    function _testCentrifugeCrosschainTransferOnboarding(
        address centrifugeVault,
        address destinationAddress,
        uint16  destinationCentrifugeId,
        uint128 expectedTransferAmount,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        bytes32 centrifugeCrosschainTransferKey = keccak256(abi.encode(GroveLiquidityLayerHelpers.LIMIT_CENTRIFUGE_TRANSFER, centrifugeVault, destinationCentrifugeId));
        bytes32 castedDestinationAddress = CastingHelpers.addressToCentrifugeRecipient(destinationAddress);

        _assertZeroRateLimit(centrifugeCrosschainTransferKey);

        executeAllPayloadsAndBridges();

        _assertRateLimit(centrifugeCrosschainTransferKey, maxAmount, slope);

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        CentrifugeV3Config memory centrifugeConfig = _prepareCentrifugeConfig(centrifugeVault);

        ICentrifugeV3ShareLike vaultToken = ICentrifugeV3ShareLike(ICentrifugeV3Vault(centrifugeConfig.centrifugeVault).share());

        _prepareCentrifugeWhitelisting(vaultToken, centrifugeConfig.centrifugeRoot);

        deal(centrifugeConfig.centrifugeAsset, address(ctx.proxy), expectedTransferAmount * 2);
        deal(ctx.relayer, 1 ether);  // Gas cost for Centrifuge

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeConfig.centrifugeVault, expectedTransferAmount * 2);

        _centrifugeV3FulfillDepositRequest(
            centrifugeConfig,
            expectedTransferAmount * 2
        );

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeConfig.centrifugeVault);

        uint256 proxyBalanceBefore     = IERC20(vaultToken).balanceOf(address(ctx.proxy));
        uint256 shareTotalSupplyBefore = IERC20(vaultToken).totalSupply();

        vm.expectEmit(centrifugeConfig.centrifugeSpoke);
        emit ISpokeLike.InitiateTransferShares(
            destinationCentrifugeId,
            centrifugeConfig.centrifugePoolId,
            centrifugeConfig.centrifugeScId,
            address(ctx.proxy),
            castedDestinationAddress,
            expectedTransferAmount
        );

        vm.startPrank(ctx.relayer);
        MainnetController(ctx.controller).transferSharesCentrifuge{value: 1 ether}(
            centrifugeConfig.centrifugeVault,
            expectedTransferAmount,
            destinationCentrifugeId
        );

        uint256 proxyBalanceAfter     = IERC20(vaultToken).balanceOf(address(ctx.proxy));
        uint256 shareTotalSupplyAfter = IERC20(vaultToken).totalSupply();

        assertEq(proxyBalanceAfter,     proxyBalanceBefore     - expectedTransferAmount);
        assertEq(shareTotalSupplyAfter, shareTotalSupplyBefore - expectedTransferAmount);
    }

    function _prepareCentrifugeConfig(address centrifugeVault) internal view returns (CentrifugeV3Config memory) {
        IAsyncRedeemManagerLike centrifugeManager = IAsyncRedeemManagerLike(ICentrifugeV3Vault(centrifugeVault).manager());
        ISpokeLike centrifugeSpoke = ISpokeLike(centrifugeManager.spoke());
        address centrifugeAsset = ICentrifugeV3Vault(centrifugeVault).asset();

        return CentrifugeV3Config({
            centrifugeVault:   centrifugeVault,
            centrifugeRoot:    ICentrifugeV3Vault(centrifugeVault).root(),
            centrifugeManager: address(centrifugeManager),
            centrifugeAsset:   centrifugeAsset,
            centrifugeSpoke:   address(centrifugeSpoke),
            centrifugeScId:    ICentrifugeV3Vault(centrifugeVault).scId(),
            centrifugePoolId:  ICentrifugeV3Vault(centrifugeVault).poolId(),
            centrifugeAssetId: centrifugeSpoke.assetToId(centrifugeAsset, 0)
        });
    }

    function _prepareCentrifugeWhitelisting(ICentrifugeV3ShareLike vaultToken, address centrifugeRoot) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        vm.startPrank(centrifugeRoot);
        IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(ctx.proxy), type(uint64).max);
        if (ChainIdUtils.fromUint(block.chainid) == ChainIdUtils.Ethereum()) {
            IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(uint160(GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID)), type(uint64).max);
            IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(uint160(GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID)),     type(uint64).max);
        } else {
            IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(uint160(GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID)), type(uint64).max);
        }
        vm.stopPrank();
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

        IAsyncRedeemManagerLike manager = IAsyncRedeemManagerLike(config.centrifugeManager);
        address poolEscrow = manager.poolEscrow(config.centrifugePoolId);
        deal(ICentrifugeV3Vault(config.centrifugeVault).asset(), poolEscrow, 5_000_000_000e6);

       // Deposit assets into balanceSheet
        deal(ICentrifugeV3Vault(config.centrifugeVault).asset(), config.centrifugeRoot, tokenAmount * 2);
        IBalanceSheetLike balanceSheet = IBalanceSheetLike(manager.balanceSheet());

        vm.startPrank(config.centrifugeRoot);
        ISpokeLike centrifugeSpoke = ISpokeLike(manager.spoke());
        centrifugeSpoke.updatePricePoolPerAsset(config.centrifugePoolId, config.centrifugeScId, config.centrifugeAssetId, 1e18, uint64(block.timestamp));

        IERC20(ICentrifugeV3Vault(config.centrifugeVault).asset()).approve(address(balanceSheet), tokenAmount * 2);
        balanceSheet.deposit(config.centrifugePoolId, config.centrifugeScId, ICentrifugeV3Vault(config.centrifugeVault).asset(), 0, uint128(tokenAmount * 2));
        vm.stopPrank();

        // Revoke shares
        vm.prank(config.centrifugeRoot);
        manager.revokedShares(
            config.centrifugePoolId,
            config.centrifugeScId,
            config.centrifugeAssetId,
            _tokenAmount * 2,
            _tokenAmount,
            2e18
        );

        // Fulfill request at price 2.0
        vm.prank(config.centrifugeRoot);
        manager.fulfillRedeemRequest(
            config.centrifugePoolId,
            config.centrifugeScId,
            address(ctx.proxy),
            config.centrifugeAssetId,
            _tokenAmount * 2,
            _tokenAmount,
            0
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

        assertEq(controller.hasRole(RELAYER, ctx.relayer), false);
        assertEq(controller.hasRole(FREEZER, ctx.freezer), false);

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(
                controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE),
                CastingHelpers.addressToCctpRecipient(address(0))
            );
        } else {
            assertEq(controller.mintRecipients(
                CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
                CastingHelpers.addressToCctpRecipient(address(0))
            );
        }

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(address(0))
            );
        } else {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(address(0))
            );
        }

        executeAllPayloadsAndBridges();

        assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), false);
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), true);

        assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), false);
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), true);

        assertEq(controller.hasRole(RELAYER, ctx.relayer), true);
        assertEq(controller.hasRole(FREEZER, ctx.freezer), true);

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(
                controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE),
                CastingHelpers.addressToCctpRecipient(Avalanche.ALM_PROXY)
            );
            // assertEq(controller.mintRecipients(
            //     CCTPForwarder.DOMAIN_ID_CIRCLE_PLUME),
            //     CastingHelpers.addressToCctpRecipient(Plume.ALM_PROXY)
            // );
        } else {
            assertEq(
                controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
                CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
            );
        }

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Avalanche.ALM_PROXY)
            );
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY)
            );
        } else {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY)
            );
        }
    }

}
