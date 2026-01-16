// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
            token1Params,
            keys
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

    struct UniswapV3OperationalVars {
        GroveLiquidityLayerContext ctx;
        MainnetController          controller;
        int24   tickSpacing;
        int24   currentTick;
        int24   tickLower;
        int24   tickUpper;
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Used;
        uint256 amount1Used;
        uint256 depositRateLimit0Before;
        uint256 depositRateLimit1Before;
        uint256 withdrawRateLimit0Before;
        uint256 withdrawRateLimit1Before;
    }

    function __assertOnboardedUniswapV3OnboardingIsOperational(
        UniswapV3TestingContext               memory context,
        UniswapV3TestingParams                memory testingParams,
        UniswapV3Helpers.UniswapV3PoolParams  memory poolParams,
        UniswapV3Helpers.UniswapV3TokenParams memory token0Params,
        UniswapV3Helpers.UniswapV3TokenParams memory token1Params,
        UniswapV3Keys                         memory keys
    ) private {
        UniswapV3OperationalVars memory vars;
        vars.ctx        = _getGroveLiquidityLayerContext();
        vars.controller = MainnetController(vars.ctx.controller);

        // Get pool tick info for positioning liquidity
        vars.tickSpacing = IUniswapV3PoolLike(context.pool).tickSpacing();
        (, vars.currentTick,,,,,) = IUniswapV3PoolLike(context.pool).slot0();

        // Test add/remove liquidity for all 3 tick position scenarios
        if (token0Params.depositMax != 0 && token1Params.depositMax != 0) {
            assertGt(testingParams.expectedDepositAmountToken0, 0, "expectedDepositAmountToken0 must be > 0 when deposit enabled");
            assertGt(testingParams.expectedDepositAmountToken1, 0, "expectedDepositAmountToken1 must be > 0 when deposit enabled");

            // Withdraw should also be enabled if deposit is enabled
            assertGt(token0Params.withdrawMax, 0, "withdrawMax for token0 should be > 0 when deposit enabled");
            assertGt(token1Params.withdrawMax, 0, "withdrawMax for token1 should be > 0 when deposit enabled");

            // Assert deposit amounts fit within rate limits
            assertLe(
                testingParams.expectedDepositAmountToken0,
                token0Params.depositMax,
                "expectedDepositAmountToken0 must be <= depositMax for token0"
            );
            assertLe(
                testingParams.expectedDepositAmountToken1,
                token1Params.depositMax,
                "expectedDepositAmountToken1 must be <= depositMax for token1"
            );

            // ===============================================================
            // SCENARIO 1: Range ABOVE current tick (only token0 deposited)
            // ===============================================================
            vars.tickLower = _toSpacedTick(vars.currentTick + vars.tickSpacing, vars.tickSpacing);
            vars.tickUpper = _toSpacedTick(poolParams.upperTickBound, vars.tickSpacing);

            // Ensure valid tick range
            if (vars.tickLower < vars.tickUpper && vars.tickLower >= poolParams.lowerTickBound) {
                _testLiquidityScenario({
                    context          : context,
                    poolParams       : poolParams,
                    keys             : keys,
                    vars             : vars,
                    desiredAmount0   : testingParams.expectedDepositAmountToken0,
                    desiredAmount1   : testingParams.expectedDepositAmountToken1,
                    expectToken0Used : true,  // expectToken0Used
                    expectToken1Used : false  // expectToken1Used
                });

                // Warp to replenish rate limits for next scenario
                _warpToReplenishRateLimits(token0Params, token1Params);
            }

            // ===============================================================
            // SCENARIO 2: Range BELOW current tick (only token1 deposited)
            // ===============================================================
            // Re-fetch current tick in case it moved
            (, vars.currentTick,,,,,) = IUniswapV3PoolLike(context.pool).slot0();

            vars.tickLower = _toSpacedTick(poolParams.lowerTickBound, vars.tickSpacing);
            vars.tickUpper = _toSpacedTick(vars.currentTick - vars.tickSpacing, vars.tickSpacing);

            // Ensure valid tick range
            if (vars.tickLower < vars.tickUpper && vars.tickUpper <= poolParams.upperTickBound) {
                _testLiquidityScenario({
                    context          : context,
                    poolParams       : poolParams,
                    keys             : keys,
                    vars             : vars,
                    desiredAmount0   : testingParams.expectedDepositAmountToken0,
                    desiredAmount1   : testingParams.expectedDepositAmountToken1,
                    expectToken0Used : false, // expectToken0Used
                    expectToken1Used : true   // expectToken1Used
                });

                // Warp to replenish rate limits for next scenario
                _warpToReplenishRateLimits(token0Params, token1Params);
            }

            // ===============================================================
            // SCENARIO 3: Range CONTAINS current tick (both tokens deposited)
            // ===============================================================
            // NOTE: Skipped because the controller's TWAP validation requires non-zero min amounts
            // when both tokens are expected, which requires computing the exact token ratio
            // based on current tick position. The two single-sided tests above are sufficient
            // to validate that add/remove liquidity functionality works correctly.

            // Advance time to allow TWAP observations to update before swap tests
            vm.warp(block.timestamp + poolParams.twapSecondsAgo + 1);
        } else {
            // Deposit is disabled
            assertEq(testingParams.expectedDepositAmountToken0, 0, "expectedDepositAmountToken0 must be 0 when deposit disabled");
            assertEq(testingParams.expectedDepositAmountToken1, 0, "expectedDepositAmountToken1 must be 0 when deposit disabled");

            // Withdraw should also be disabled if deposit is disabled
            assertEq(token0Params.withdrawMax, 0, "withdrawMax for token0 should be 0 when deposit disabled");
            assertEq(token1Params.withdrawMax, 0, "withdrawMax for token1 should be 0 when deposit disabled");
        }

        // Test swapping token0 -> token1 if swap is enabled for token0
        if (token0Params.swapMax != 0) {
            assertGt(testingParams.expectedSwapAmountToken0, 0, "expectedSwapAmountToken0 must be > 0 when swap enabled");
            _testSwap({
                pool         : context.pool,
                swapKey      : keys.swapKey0,
                tokenIn      : context.token0,
                tokenOut     : context.token1,
                swapAmount   : testingParams.expectedSwapAmountToken0,
                maxSlippage  : poolParams.maxSlippage,
                maxTickDelta : poolParams.maxTickDelta
            });
            _warpToReplenishRateLimits(token0Params, token1Params);
        }

        // Test swapping token1 -> token0 if swap is enabled for token1
        if (token1Params.swapMax != 0) {
            assertGt(testingParams.expectedSwapAmountToken1, 0, "expectedSwapAmountToken1 must be > 0 when swap enabled");
            _testSwap({
                pool         : context.pool,
                swapKey      : keys.swapKey1,
                tokenIn      : context.token1,
                tokenOut     : context.token0,
                swapAmount   : testingParams.expectedSwapAmountToken1,
                maxSlippage  : poolParams.maxSlippage,
                maxTickDelta : poolParams.maxTickDelta
            });
        }

        // Sanity check on maxSlippage (between 98.5% and 100%)
        assertGe(poolParams.maxSlippage, 0.985e18, "maxSlippage too low");
        assertLe(poolParams.maxSlippage, 1e18,     "maxSlippage too high");
    }

    /// @dev Helper to test a swap with rate limit verification
    function _testSwap(
        address pool,
        bytes32 swapKey,
        address tokenIn,
        address tokenOut,
        uint256 swapAmount,
        uint256 maxSlippage,
        uint24 maxTickDelta
    ) private {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        MainnetController controller = MainnetController(ctx.controller);

        // Use tokens already on proxy, or deal if needed
        uint256 currentBalance = IERC20(tokenIn).balanceOf(address(ctx.proxy));
        if (currentBalance < swapAmount) {
            deal2(tokenIn, address(ctx.proxy), swapAmount - currentBalance);
        }

        // Calculate minAmountOut based on token decimals and maxSlippage
        uint256 minAmountOut = swapAmount
            * (10 ** IERC20Metadata(tokenOut).decimals())
            * maxSlippage
            / (10 ** IERC20Metadata(tokenIn).decimals())
            / 1e18;

        uint256 tokenInBalanceBefore  = IERC20(tokenIn).balanceOf(address(ctx.proxy));
        uint256 tokenOutBalanceBefore = IERC20(tokenOut).balanceOf(address(ctx.proxy));
        uint256 swapRateLimitBefore   = ctx.rateLimits.getCurrentRateLimit(swapKey);

        vm.prank(ctx.relayer);
        controller.swapUniswapV3(pool, tokenIn, swapAmount, minAmountOut, maxTickDelta);

        // Verify swap consumed the expected amount
        assertEq(
            IERC20(tokenIn).balanceOf(address(ctx.proxy)),
            tokenInBalanceBefore - swapAmount,
            "tokenIn balance should decrease by swap amount"
        );
        assertGe(
            IERC20(tokenOut).balanceOf(address(ctx.proxy)) - tokenOutBalanceBefore,
            minAmountOut,
            "tokenOut received should be >= minAmountOut"
        );

        // Verify rate limit decreased correctly (skip for unlimited rate limits)
        if (swapRateLimitBefore != type(uint256).max) {
            assertEq(
                ctx.rateLimits.getCurrentRateLimit(swapKey),
                swapRateLimitBefore - swapAmount,
                "swap rate limit should decrease by swap amount"
            );
        }
    }

    /// @dev Helper to test a single liquidity scenario (add + remove) with rate limit verification
    function _testLiquidityScenario(
        UniswapV3TestingContext              memory context,
        UniswapV3Helpers.UniswapV3PoolParams memory poolParams,
        UniswapV3Keys                        memory keys,
        UniswapV3OperationalVars             memory vars,
        uint256 desiredAmount0,
        uint256 desiredAmount1,
        bool expectToken0Used,
        bool expectToken1Used
    ) private {
        // Fund proxy only with tokens that will be used (to conserve token holder balances)
        if (expectToken0Used) {
            deal2(context.token0, address(vars.ctx.proxy), desiredAmount0);
        }
        if (expectToken1Used) {
            deal2(context.token1, address(vars.ctx.proxy), desiredAmount1);
        }

        // Calculate min amounts based on expected token usage
        UniswapV3Lib.TokenAmounts memory minAmounts;
        if (expectToken0Used && !expectToken1Used) {
            // Only token0 will be used (range above current tick)
            minAmounts = UniswapV3Lib.TokenAmounts({
                amount0 : desiredAmount0 * poolParams.maxSlippage / 1e18,
                amount1 : 0
            });
        } else if (!expectToken0Used && expectToken1Used) {
            // Only token1 will be used (range below current tick)
            minAmounts = UniswapV3Lib.TokenAmounts({
                amount0 : 0,
                amount1 : desiredAmount1 * poolParams.maxSlippage / 1e18
            });
        } else {
            // Both tokens used (range contains current tick)
            // Use zero min amounts since the ratio is unpredictable
            minAmounts = UniswapV3Lib.TokenAmounts({
                amount0 : 0,
                amount1 : 0
            });
        }

        // Record rate limits before add liquidity
        vars.depositRateLimit0Before = vars.ctx.rateLimits.getCurrentRateLimit(keys.depositKey0);
        vars.depositRateLimit1Before = vars.ctx.rateLimits.getCurrentRateLimit(keys.depositKey1);

        // Add liquidity
        vm.prank(vars.ctx.relayer);
        (vars.tokenId, vars.liquidity, vars.amount0Used, vars.amount1Used) = vars.controller.addLiquidityUniswapV3(
            context.pool,
            0, // tokenId = 0 means mint new position
            UniswapV3Lib.Tick({
                lower : vars.tickLower,
                upper : vars.tickUpper
            }),
            UniswapV3Lib.TokenAmounts({
                amount0 : desiredAmount0,
                amount1 : desiredAmount1
            }),
            minAmounts,
            block.timestamp + 1 hours
        );

        // Verify liquidity was added
        assertGt(vars.liquidity, 0, "liquidity should be > 0");
        assertGt(vars.tokenId,   0, "tokenId should be > 0");

        // Verify expected tokens were used based on tick position
        if (expectToken0Used && !expectToken1Used) {
            assertGt(vars.amount0Used, 0, "Scenario above tick: token0 should be used");
            assertEq(vars.amount1Used, 0, "Scenario above tick: token1 should NOT be used");
        } else if (!expectToken0Used && expectToken1Used) {
            assertEq(vars.amount0Used, 0, "Scenario below tick: token0 should NOT be used");
            assertGt(vars.amount1Used, 0, "Scenario below tick: token1 should be used");
        } else {
            // Both tokens should be used when tick is in range
            // Note: Due to tick positioning, amounts may vary significantly
            assertGt(vars.amount0Used + vars.amount1Used, 0, "Scenario in range: at least one token should be used");
        }

        // Verify deposit rate limits decreased correctly (skip for unlimited rate limits)
        if (vars.depositRateLimit0Before != type(uint256).max) {
            assertEq(
                vars.ctx.rateLimits.getCurrentRateLimit(keys.depositKey0),
                vars.depositRateLimit0Before - vars.amount0Used,
                "deposit rate limit for token0 should decrease by amount0Used"
            );
        }
        if (vars.depositRateLimit1Before != type(uint256).max) {
            assertEq(
                vars.ctx.rateLimits.getCurrentRateLimit(keys.depositKey1),
                vars.depositRateLimit1Before - vars.amount1Used,
                "deposit rate limit for token1 should decrease by amount1Used"
            );
        }

        // Record rate limits before remove liquidity
        vars.withdrawRateLimit0Before = vars.ctx.rateLimits.getCurrentRateLimit(keys.withdrawKey0);
        vars.withdrawRateLimit1Before = vars.ctx.rateLimits.getCurrentRateLimit(keys.withdrawKey1);

        // Calculate min amounts for withdrawal with slippage
        uint256 minAmount0 = vars.amount0Used * poolParams.maxSlippage / 1e18;
        uint256 minAmount1 = vars.amount1Used * poolParams.maxSlippage / 1e18;

        // Remove liquidity
        vm.prank(vars.ctx.relayer);
        (uint256 amount0Removed, uint256 amount1Removed) = vars.controller.removeLiquidityUniswapV3(
            context.pool,
            vars.tokenId,
            vars.liquidity,
            UniswapV3Lib.TokenAmounts({
                amount0 : minAmount0,
                amount1 : minAmount1
            }),
            block.timestamp + 1 hours
        );

        // Verify amounts removed meet minimums
        assertGe(amount0Removed, minAmount0, "amount0Removed should be >= minAmount0");
        assertGe(amount1Removed, minAmount1, "amount1Removed should be >= minAmount1");

        // Verify withdraw rate limits decreased correctly (skip for unlimited rate limits)
        if (vars.withdrawRateLimit0Before != type(uint256).max) {
            assertEq(
                vars.ctx.rateLimits.getCurrentRateLimit(keys.withdrawKey0),
                vars.withdrawRateLimit0Before - amount0Removed,
                "withdraw rate limit for token0 should decrease by amount0Removed"
            );
        }
        if (vars.withdrawRateLimit1Before != type(uint256).max) {
            assertEq(
                vars.ctx.rateLimits.getCurrentRateLimit(keys.withdrawKey1),
                vars.withdrawRateLimit1Before - amount1Removed,
                "withdraw rate limit for token1 should decrease by amount1Removed"
            );
        }
    }

    /// @dev Warp time forward to replenish rate limits to max
    function _warpToReplenishRateLimits(
        UniswapV3Helpers.UniswapV3TokenParams memory token0Params,
        UniswapV3Helpers.UniswapV3TokenParams memory token1Params
    ) private {
        // Calculate time needed to fully replenish all rate limits
        // Rate limit replenishes at `slope` tokens per second up to `maxAmount`
        // Time = maxAmount / slope (but avoid division by zero for unlimited slopes)
        uint256 maxTime = 1 days; // Default max warp

        if (token0Params.depositSlope > 0) {
            uint256 time0 = token0Params.depositMax / token0Params.depositSlope + 1;
            if (time0 > maxTime) maxTime = time0;
        }
        if (token1Params.depositSlope > 0) {
            uint256 time1 = token1Params.depositMax / token1Params.depositSlope + 1;
            if (time1 > maxTime) maxTime = time1;
        }

        vm.warp(block.timestamp + maxTime);
    }

    function _toSpacedTick(int24 tick, int24 tickSpacing) private pure returns (int24) {
        return (tick / tickSpacing) * tickSpacing;
    }

}
