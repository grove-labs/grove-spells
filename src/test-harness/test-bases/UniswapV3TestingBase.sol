// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { UniswapV3Lib } from "lib/grove-alm-controller/src/libraries/UniswapV3Lib.sol";

import { IUniswapV3PoolLike, UniswapV3Helpers } from "src/libraries/helpers/UniswapV3Helpers.sol";
import { GroveLiquidityLayerHelpers }           from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveLiquidityLayerContext, CommonTestBase } from "../CommonTestBase.sol";

abstract contract UniswapV3TestingBase is CommonTestBase {

    struct UniswapV3TestingContext {
        address pool;
        address token0;
        address token1;
    }

    struct UniswapV3TestingParams {
        uint256 expectedDepositAmountToken0;
        uint256 expectedSwapAmountToken0;
        uint256 expectedDepositAmountToken1;
        uint256 expectedSwapAmountToken1;
    }

    struct UniswapV3Keys {
        bytes32 swapKey0;
        bytes32 depositKey0;
        bytes32 withdrawKey0;
        bytes32 swapKey1;
        bytes32 depositKey1;
        bytes32 withdrawKey1;
    }

    function _testUniswapV3Onboarding(
        UniswapV3TestingContext               memory context,
        UniswapV3TestingParams                memory testingParams,
        UniswapV3Helpers.UniswapV3PoolParams  memory poolParams,
        UniswapV3Helpers.UniswapV3TokenParams memory token0Params,
        UniswapV3Helpers.UniswapV3TokenParams memory token1Params
    ) internal {
        UniswapV3Keys memory keys;
        keys.swapKey0 = RateLimitHelpers.makeAssetDestinationKey(
            GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_SWAP,
            context.token0,
            context.pool
        );
        keys.depositKey0 = RateLimitHelpers.makeAssetDestinationKey(
            GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_DEPOSIT,
            context.token0,
            context.pool
        );
        keys.withdrawKey0 = RateLimitHelpers.makeAssetDestinationKey(
            GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_WITHDRAW,
            context.token0,
            context.pool
        );
        keys.swapKey1 = RateLimitHelpers.makeAssetDestinationKey(
            GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_SWAP,
            context.token1,
            context.pool
        );
        keys.depositKey1 = RateLimitHelpers.makeAssetDestinationKey(
            GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_DEPOSIT,
            context.token1,
            context.pool
        );
        keys.withdrawKey1 = RateLimitHelpers.makeAssetDestinationKey(
            GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_WITHDRAW,
            context.token1,
            context.pool
        );

        __assertClearedUniswapV3ConfigState(
            context,
            keys
        );

        executeAllPayloadsAndBridges();

        __assertSetUniswapV3ConfigState(
            context,
            keys,
            poolParams,
            token0Params,
            token1Params
        );

        __assertOnboardedUniswapV3OnboardingIsOperational(
            context,
            testingParams,
            poolParams,
            token0Params,
            token1Params
        );
    }

    function __assertClearedUniswapV3ConfigState(
        UniswapV3TestingContext memory context,
        UniswapV3Keys           memory keys
    ) private view {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        MainnetController controller = MainnetController(ctx.controller);

        assertEq(IUniswapV3PoolLike(context.pool).token0(), context.token0, "incorrect-token0");
        assertEq(IUniswapV3PoolLike(context.pool).token1(), context.token1, "incorrect-token1");

        (
            uint24 controllerPoolSwapMaxTickDelta,
            UniswapV3Lib.Tick memory controllerPoolTickBounds,
            uint32 controllerPoolTwapSecondsAgo
        ) = controller.uniswapV3PoolParams(context.pool);

        assertEq(controllerPoolTickBounds.lower,        0, "non-zero-lowerTickBound");
        assertEq(controllerPoolTickBounds.upper,        0, "non-zero-upperTickBound");
        assertEq(controllerPoolTwapSecondsAgo,          0, "non-zero-twapSecondsAgo");
        assertEq(controllerPoolSwapMaxTickDelta,        0, "non-zero-maxTickDelta");
        assertEq(controller.maxSlippages(context.pool), 0, "non-zero-maxSlippage");

        _assertZeroRateLimit(keys.swapKey0);
        _assertZeroRateLimit(keys.depositKey0);
        _assertZeroRateLimit(keys.withdrawKey0);
        _assertZeroRateLimit(keys.swapKey1);
        _assertZeroRateLimit(keys.depositKey1);
        _assertZeroRateLimit(keys.withdrawKey1);
    }

    function __assertSetUniswapV3ConfigState(
        UniswapV3TestingContext               memory context,
        UniswapV3Keys                         memory keys,
        UniswapV3Helpers.UniswapV3PoolParams  memory poolParams,
        UniswapV3Helpers.UniswapV3TokenParams memory token0Params,
        UniswapV3Helpers.UniswapV3TokenParams memory token1Params
    ) private view {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        MainnetController controller = MainnetController(ctx.controller);

        (
            uint24 controllerPoolSwapMaxTickDelta,
            UniswapV3Lib.Tick memory controllerPoolTickBounds,
            uint32 controllerPoolTwapSecondsAgo
        ) = controller.uniswapV3PoolParams(context.pool);

        assertEq(controllerPoolTickBounds.lower,        poolParams.lowerTickBound, "incorrect-lowerTickBound");
        assertEq(controllerPoolTickBounds.upper,        poolParams.upperTickBound, "incorrect-upperTickBound");
        assertEq(controllerPoolTwapSecondsAgo,          poolParams.twapSecondsAgo, "incorrect-twapSecondsAgo");
        assertEq(controllerPoolSwapMaxTickDelta,        poolParams.maxTickDelta,   "incorrect-maxTickDelta");
        assertEq(controller.maxSlippages(context.pool), poolParams.maxSlippage,    "incorrect-maxSlippage");

        _assertRateLimit(keys.swapKey0,     token0Params.swapMax,     token0Params.swapSlope);
        _assertRateLimit(keys.depositKey0,  token0Params.depositMax,  token0Params.depositSlope);
        _assertRateLimit(keys.withdrawKey0, token0Params.withdrawMax, token0Params.withdrawSlope);
        _assertRateLimit(keys.swapKey1,     token1Params.swapMax,     token1Params.swapSlope);
        _assertRateLimit(keys.depositKey1,  token1Params.depositMax,  token1Params.depositSlope);
        _assertRateLimit(keys.withdrawKey1, token1Params.withdrawMax, token1Params.withdrawSlope);
    }

    function __assertOnboardedUniswapV3OnboardingIsOperational(
        UniswapV3TestingContext               memory context,
        UniswapV3TestingParams                memory testingParams,
        UniswapV3Helpers.UniswapV3PoolParams  memory poolParams,
        UniswapV3Helpers.UniswapV3TokenParams memory token0Params,
        UniswapV3Helpers.UniswapV3TokenParams memory token1Params
    ) private view {
        // TODO Test flow of swapping, adding liquidity, and removing liquidity
    }

}
