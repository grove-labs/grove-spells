// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveLiquidityLayerContext, CommonTestBase } from "../CommonTestBase.sol";

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

abstract contract CurveTestingBase is CommonTestBase {

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

            deal2(vars.pool.coins(0), address(vars.ctx.proxy), vars.depositAmounts[0]);
            deal2(vars.pool.coins(1), address(vars.ctx.proxy), vars.depositAmounts[1]);

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

            uint256 snapshot = vm.snapshotState();

            // Go slightly above maxSlippage due to rounding
            vars.withdrawAmounts = new uint256[](2);
            vars.withdrawAmounts[0] = vars.lpBalance * vars.pool.balances(0) * (maxSlippage + 0.001e18) / vars.pool.totalSupply() / 1e18;
            vars.withdrawAmounts[1] = vars.lpBalance * vars.pool.balances(1) * (maxSlippage + 0.001e18) / vars.pool.totalSupply() / 1e18;

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

            vm.revertToState(snapshot);  // To allow swapping through higher liquidity below
        } else {
            // Deposit is disabled
            assertEq(vars.depositAmounts[0], 0);
            assertEq(vars.depositAmounts[1], 0);

            // Withdraw should also be disabled if deposit is disabled
            assertEq(withdrawMax, 0);
        }

        if (swapMax != 0) {
            deal2(vars.pool.coins(0), address(vars.ctx.proxy), expectedSwapAmountToken0);
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
    }

}
