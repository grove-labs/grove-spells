// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { IAToken } from "aave-v3-origin/src/core/contracts/interfaces/IAToken.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "grove-address-registry/Avalanche.sol";
import { Ethereum }  from "grove-address-registry/Ethereum.sol";
import { Plume }     from "grove-address-registry/Plume.sol";
import { Base }      from "grove-address-registry/Base.sol";
import { Plasma }    from "grove-address-registry/Plasma.sol";

import { IALMProxy }         from "grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { ChainId, ChainIdUtils }      from "src/libraries/helpers/ChainId.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveLiquidityLayerContext, CommonTestBase } from "../CommonTestBase.sol";

import { SpellRunner } from "../SpellRunner.sol";

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

interface ICentrifugeV3ShareLike {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
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
    function updatePricePoolPerAsset(uint64 poolId, bytes16 scId, uint128 assetId, uint128 poolPerAsset_, uint64 computedAt) external;
    function markersPricePoolPerAsset(uint64 poolId, bytes16 scId, uint128 assetId)
        external
        view
        returns (uint64 computedAt, uint64 maxAge, uint64 validUntil);
    event InitiateTransferShares(
        uint16 centrifugeId,
        uint64 indexed poolId,
        bytes16 indexed scId,
        address indexed sender,
        bytes32 destinationAddress,
        uint128 amount
    );
}

interface ICurvePoolLike {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function add_liquidity(
        uint256[] memory amounts,
        uint256 minMintAmount,
        address receiver
    ) external;
    function balances(uint256 index) external view returns (uint256);
    function coins(uint256 index) external returns (address);
    function exchange(
        int128  inputIndex,
        int128  outputIndex,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver
    ) external returns (uint256 tokensOut);
    function get_virtual_price() external view returns (uint256);
    function N_COINS() external view returns (uint256);
    function remove_liquidity(
        uint256 burnAmount,
        uint256[] memory minAmounts,
        address receiver
    ) external;
    function stored_rates() external view returns (uint256[] memory);
}

abstract contract GroveLiquidityLayerTests is CommonTestBase {


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

    function _testAaveOnboarding(
        address aToken,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        bool unlimitedDeposit = depositMax == type(uint256).max;

        // Note: Aave signature is the same for mainnet and foreign
        deal(IAToken(aToken).UNDERLYING_ASSET_ADDRESS(), address(ctx.proxy), expectedDepositAmount);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_AAVE_DEPOSIT,
            aToken
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_AAVE_WITHDRAW,
            aToken
        );

        _assertZeroRateLimit(depositKey);
        _assertZeroRateLimit(withdrawKey);

        vm.prank(ctx.relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        MainnetController(ctx.controller).depositAave(aToken, expectedDepositAmount);

        executeAllPayloadsAndBridges();

        // Reload the context after spell execution to get the new controller after potential controller upgrade
        ctx = _getGroveLiquidityLayerContext();

        _assertRateLimit(depositKey, depositMax, depositSlope);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        if (expectedDepositAmount == 0) return; // Skip the rest of the test if no deposit is expected

        if (!unlimitedDeposit) {
            vm.prank(ctx.relayer);
            vm.expectRevert("RateLimits/rate-limit-exceeded");
            MainnetController(ctx.controller).depositAave(aToken, depositMax + 1);
        }

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  depositMax);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).depositAave(aToken, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).withdrawAave(aToken, expectedDepositAmount / 2);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        if (!unlimitedDeposit) {
            // Do some sanity checks on the slope
            // This is to catch things like forgetting to divide to a per-second time, etc

            // We assume it takes at least 1 day to recharge to max
            uint256 dailySlope = depositSlope * 1 days;
            assertLe(dailySlope, depositMax);

            // It shouldn't take more than 30 days to recharge to max
            uint256 monthlySlope = depositSlope * 30 days;
            assertGe(monthlySlope, depositMax);
        }
    }

    struct CurveOnboardingVars {
        ICurvePoolLike pool;
        GroveLiquidityLayerContext ctx;
        MainnetController controller;
        uint256[] depositAmounts;
        uint256 minLPAmount;
        uint256[] withdrawAmounts;
        uint256[] rates;
        bytes32 swapKey;
        bytes32 depositKey;
        bytes32 withdrawKey;
        uint256 minAmountOut;
        uint256 lpBalance;
    }

    function _testCurveOnboarding(
        address pool,
        uint256 expectedDepositAmountToken0,
        uint256 expectedSwapAmountToken0,
        uint256 maxSlippage,
        uint256 swapMax,
        uint256 swapSlope,
        uint256 depositMax,
        uint256 depositSlope,
        uint256 withdrawMax,
        uint256 withdrawSlope
    ) internal {
        // Avoid stack too deep
        CurveOnboardingVars memory vars;
        vars.pool  = ICurvePoolLike(pool);
        vars.rates = ICurvePoolLike(pool).stored_rates();

        assertEq(vars.pool.N_COINS(), 2, "Curve pool must have 2 coins");

        vars.ctx        = _getGroveLiquidityLayerContext();
        vars.controller = MainnetController(vars.ctx.controller);

        vars.depositAmounts = new uint256[](2);
        vars.depositAmounts[0] = expectedDepositAmountToken0;
        // Derive the second amount to be balanced with the first
        vars.depositAmounts[1] = expectedDepositAmountToken0 * vars.rates[0] / vars.rates[1];

        vars.minLPAmount = (
            vars.depositAmounts[0] * vars.rates[0] +
            vars.depositAmounts[1] * vars.rates[1]
        ) * maxSlippage / 1e18 / vars.pool.get_virtual_price();

        vars.swapKey     = RateLimitHelpers.makeAssetKey(GroveLiquidityLayerHelpers.LIMIT_CURVE_SWAP,     pool);
        vars.depositKey  = RateLimitHelpers.makeAssetKey(GroveLiquidityLayerHelpers.LIMIT_CURVE_DEPOSIT,  pool);
        vars.withdrawKey = RateLimitHelpers.makeAssetKey(GroveLiquidityLayerHelpers.LIMIT_CURVE_WITHDRAW, pool);

        _assertZeroRateLimit(vars.swapKey);
        _assertZeroRateLimit(vars.depositKey);
        _assertZeroRateLimit(vars.withdrawKey);

        assertEq(vars.controller.maxSlippages(pool), 0);

        executeAllPayloadsAndBridges();

        // Reload the context after spell execution to get the new controller after potential controller upgrade
        vars.ctx        = _getGroveLiquidityLayerContext();
        vars.controller = MainnetController(vars.ctx.controller);

        _assertRateLimit(vars.swapKey,     swapMax,     swapSlope);
        _assertRateLimit(vars.depositKey,  depositMax,  depositSlope);
        _assertRateLimit(vars.withdrawKey, withdrawMax, withdrawSlope);

        assertEq(vars.controller.maxSlippages(pool), maxSlippage);

        if (depositMax != 0) {
            // Deposit is enabled
            assertGt(vars.depositAmounts[0], 0);
            assertGt(vars.depositAmounts[1], 0);

            deal(vars.pool.coins(0), address(vars.ctx.proxy), vars.depositAmounts[0]);
            deal(vars.pool.coins(1), address(vars.ctx.proxy), vars.depositAmounts[1]);

            assertEq(IERC20(vars.pool.coins(0)).balanceOf(address(vars.ctx.proxy)), vars.depositAmounts[0]);
            assertEq(IERC20(vars.pool.coins(1)).balanceOf(address(vars.ctx.proxy)), vars.depositAmounts[1]);

            vm.prank(vars.ctx.relayer);
            vars.controller.addLiquidityCurve(
                pool,
                vars.depositAmounts,
                vars.minLPAmount
            );

            assertEq(IERC20(vars.pool.coins(0)).balanceOf(address(vars.ctx.proxy)), 0);
            assertEq(IERC20(vars.pool.coins(1)).balanceOf(address(vars.ctx.proxy)), 0);

            vars.lpBalance = vars.pool.balanceOf(address(vars.ctx.proxy));
            assertGe(vars.lpBalance, vars.minLPAmount);

            // Withdraw should also be enabled if deposit is enabled
            assertGt(withdrawMax, 0);

            uint256 snapshot = vm.snapshot();

            // Go slightly above maxSlippage due to rounding
            vars.withdrawAmounts = new uint256[](2);
            vars.withdrawAmounts[0] = vars.lpBalance * vars.pool.balances(0) * (maxSlippage + 0.001e18) / vars.pool.get_virtual_price() / vars.pool.totalSupply();
            vars.withdrawAmounts[1] = vars.lpBalance * vars.pool.balances(1) * (maxSlippage + 0.001e18) / vars.pool.get_virtual_price() / vars.pool.totalSupply();

            vm.prank(vars.ctx.relayer);
            vars.controller.removeLiquidityCurve(
                pool,
                vars.lpBalance,
                vars.withdrawAmounts
            );

            assertEq(vars.pool.balanceOf(address(vars.ctx.proxy)), 0);
            assertGe(IERC20(vars.pool.coins(0)).balanceOf(address(vars.ctx.proxy)), vars.withdrawAmounts[0]);
            assertGe(IERC20(vars.pool.coins(1)).balanceOf(address(vars.ctx.proxy)), vars.withdrawAmounts[1]);

            // Ensure that value withdrawn is greater than the value deposited * maxSlippage (18 decimal precision)
            assertGe(
                (vars.withdrawAmounts[0] * vars.rates[0] + vars.withdrawAmounts[1] * vars.rates[1]) / 1e18,
                (vars.depositAmounts[0] * vars.rates[0] + vars.depositAmounts[1] * vars.rates[1]) * maxSlippage / 1e36
            );

            vm.revertTo(snapshot);  // To allow swapping through higher liquidity below
        } else {
            // Deposit is disabled
            assertEq(vars.depositAmounts[0], 0);
            assertEq(vars.depositAmounts[1], 0);

            // Withdraw should also be disabled if deposit is disabled
            assertEq(withdrawMax, 0);
        }

        deal(vars.pool.coins(0), address(vars.ctx.proxy), expectedSwapAmountToken0);
        vars.minAmountOut = expectedSwapAmountToken0 * vars.rates[0] * maxSlippage / vars.rates[1] / 1e18;

        assertEq(IERC20(vars.pool.coins(0)).balanceOf(address(vars.ctx.proxy)), expectedSwapAmountToken0);
        assertEq(IERC20(vars.pool.coins(1)).balanceOf(address(vars.ctx.proxy)), 0);

        vm.prank(vars.ctx.relayer);
        uint256 amountOut = vars.controller.swapCurve(
            pool,
            0,
            1,
            expectedSwapAmountToken0,
            vars.minAmountOut
        );

        assertEq(IERC20(vars.pool.coins(0)).balanceOf(address(vars.ctx.proxy)), 0);
        assertEq(IERC20(vars.pool.coins(1)).balanceOf(address(vars.ctx.proxy)), amountOut);
        assertGe(IERC20(vars.pool.coins(1)).balanceOf(address(vars.ctx.proxy)), vars.minAmountOut);

        // Overwrite minAmountOut based on returned amount to swap back to token0
        vars.minAmountOut = amountOut * vars.rates[1] * maxSlippage / vars.rates[0] / 1e18;

        vm.prank(vars.ctx.relayer);
        amountOut = vars.controller.swapCurve(
            pool,
            1,
            0,
            amountOut,
            vars.minAmountOut
        );

        assertEq(IERC20(vars.pool.coins(0)).balanceOf(address(vars.ctx.proxy)), amountOut);
        assertGe(IERC20(vars.pool.coins(0)).balanceOf(address(vars.ctx.proxy)), vars.minAmountOut);
        assertEq(IERC20(vars.pool.coins(1)).balanceOf(address(vars.ctx.proxy)), 0);

        // Sanity check on maxSlippage of 15bps
        assertGe(maxSlippage, 0.9985e18, "maxSlippage too low");
        assertLe(maxSlippage, 1e18,      "maxSlippage too high");
    }

    function _testCentrifugeV3RedemptionsOnlyOnboarding(
        address centrifugeVault,
        uint256 redeemMax,
        uint256 redeemSlope
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

        _assertZeroRateLimit(depositKey);
        _assertRateLimit(redeemKey, redeemMax, redeemSlope);

        IERC20 asset = IERC20(ICentrifugeV3Vault(centrifugeVault).asset());

        uint256 startShareBalance = vaultToken.balanceOf(address(ctx.proxy));

        vm.prank(ctx.admin);
        IRateLimits(ctx.rateLimits).setRateLimitData(depositKey, redeemMax * 2, 0);
        deal(address(asset), address(ctx.proxy), redeemMax * 2);
        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeVault, redeemMax * 2);
        _centrifugeV3FulfillDepositRequest(
            centrifugeConfig,
            redeemMax * 2
        );
        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeVault);
        vm.prank(ctx.admin);
        IRateLimits(ctx.rateLimits).setRateLimitData(depositKey, 0, 0);

        _assertZeroRateLimit(depositKey);
        _assertRateLimit(redeemKey, redeemMax, redeemSlope);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance + redeemMax);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestRedeemERC7540(centrifugeVault, redeemMax);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        _centrifugeV3FulfillRedeemRequest(
            centrifugeConfig,
            redeemMax
        );

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimRedeemERC7540(centrifugeVault);

        assertEq(asset.balanceOf(address(ctx.proxy)),      redeemMax * 2);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);
    }

    function _testCentrifugeV3Onboarding(
        address centrifugeVault,
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

        IERC20 asset = IERC20(ICentrifugeV3Vault(centrifugeVault).asset());

        deal(address(asset), address(ctx.proxy), depositMax);

        _assertRateLimit(depositKey, depositMax,        depositSlope);
        _assertRateLimit(redeemKey,  type(uint256).max, 0);

        uint256 startShareBalance = vaultToken.balanceOf(address(ctx.proxy));

        assertEq(asset.balanceOf(address(ctx.proxy)),      depositMax);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeVault, depositMax);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 0);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        _centrifugeV3FulfillDepositRequest(
            centrifugeConfig,
            depositMax
        );

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeVault);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance + depositMax / 2);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestRedeemERC7540(centrifugeVault, depositMax / 2);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        _centrifugeV3FulfillRedeemRequest(
            centrifugeConfig,
            depositMax / 2
        );

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimRedeemERC7540(centrifugeVault);

        assertEq(asset.balanceOf(address(ctx.proxy)),      depositMax);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);
    }


    function _testCentrifugeCrosschainTransferOnboarding(
        address centrifugeVault,
        address destinationAddress,
        uint16  destinationCentrifugeId,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        bytes32 centrifugeCrosschainTransferKey = keccak256(abi.encode(GroveLiquidityLayerHelpers.LIMIT_CENTRIFUGE_TRANSFER, centrifugeVault, destinationCentrifugeId));
        bytes32 castedDestinationAddress = CastingHelpers.addressToCentrifugeRecipient(destinationAddress);
        uint128 expectedTransferAmount = uint128(maxAmount);

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

        uint256 proxyBalanceBefore     = vaultToken.balanceOf(address(ctx.proxy));
        uint256 shareTotalSupplyBefore = vaultToken.totalSupply();

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

        uint256 proxyBalanceAfter     = vaultToken.balanceOf(address(ctx.proxy));
        uint256 shareTotalSupplyAfter = vaultToken.totalSupply();

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
        (uint64 computedAt,,)= centrifugeSpoke.markersPricePoolPerAsset(config.centrifugePoolId, config.centrifugeScId, config.centrifugeAssetId);
        if (computedAt == 0) {
            // Sets initial asset price to 1.00
            centrifugeSpoke.updatePricePoolPerAsset(config.centrifugePoolId, config.centrifugeScId, config.centrifugeAssetId, 1e18, uint64(block.timestamp));
        }

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
            // Plume intentionally skipped - CCTPv1 is not deployed on Plume
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
