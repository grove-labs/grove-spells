// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerContext, CommonTestBase } from "../CommonTestBase.sol";

abstract contract ERC20TestingBase is CommonTestBase {

    /**********************************************************************************************/
    /*** Testing functions                                                                      ***/
    /**********************************************************************************************/

    function _testDirectTokenTransferOnboarding(
        address token,
        address destination,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        deal2(token, address(ctx.proxy), expectedDepositAmount);

        __runDirectTokenTransferOnboardingTests(token, destination, expectedDepositAmount, depositMax, depositSlope);
    }

    function _testUnlimitedDirectTokenTransferOnboarding(
        address token,
        address destination,
        uint256 expectedDepositAmount
    ) internal {
        _testDirectTokenTransferOnboarding(token, destination, expectedDepositAmount, type(uint256).max, 0);
    }

    function _testDirectUsdcTransferOnboarding(
        address usdc,
        address destination,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        uint256 initialUsdcBalance = IERC20(usdc).balanceOf(address(ctx.proxy));

        if (initialUsdcBalance > expectedDepositAmount) {
            uint256 usdcSurplus = initialUsdcBalance - expectedDepositAmount;

            vm.startPrank(ctx.relayer);
            MainnetController(ctx.controller).swapUSDCToUSDS(usdcSurplus);
            MainnetController(ctx.controller).burnUSDS(usdcSurplus * 1e12);
            vm.stopPrank();

        }

        if (initialUsdcBalance < expectedDepositAmount) {
            uint256 usdcDeficit = expectedDepositAmount - initialUsdcBalance;

            vm.startPrank(ctx.relayer);
            MainnetController(ctx.controller).mintUSDS(usdcDeficit * 1e12);
            MainnetController(ctx.controller).swapUSDSToUSDC(usdcDeficit);
            vm.stopPrank();
        }

        __runDirectTokenTransferOnboardingTests(
            usdc,
            destination,
            expectedDepositAmount,
            depositMax,
            depositSlope
        );
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

    function __runDirectTokenTransferOnboardingTests(
        address token,
        address destination,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) private {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        bool unlimitedDeposit = depositMax == type(uint256).max;

        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            token,
            destination
        );

        _assertZeroRateLimit(depositKey);

        executeAllPayloadsAndBridges();

        ctx = _getGroveLiquidityLayerContext();

        _assertRateLimit(depositKey, depositMax, depositSlope);

        if (!unlimitedDeposit) {
            vm.prank(ctx.relayer);
            vm.expectRevert("RateLimits/rate-limit-exceeded");
            MainnetController(ctx.controller).transferAsset(token, destination, depositMax + 1);
        }

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);

        uint256 initialDestinationBalance = IERC20(token).balanceOf(destination);

        assertEq(IERC20(token).balanceOf(address(ctx.proxy)), expectedDepositAmount);
        assertEq(IERC20(token).balanceOf(destination), initialDestinationBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).transferAsset(token, destination, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);

        assertEq(IERC20(token).balanceOf(address(ctx.proxy)), 0);
        assertEq(IERC20(token).balanceOf(destination), initialDestinationBalance + expectedDepositAmount);

        if (!unlimitedDeposit) {
            vm.warp(block.timestamp + 1 days + 1 seconds);

            assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);
        }
    }

}
