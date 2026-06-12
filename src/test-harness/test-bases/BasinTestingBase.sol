// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { PAUContext, CommonPAUTestBase } from "../CommonPAUTestBase.sol";

interface IBasinFacetLike {
    function deposit(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external returns (uint256 shares);
    function withdraw(address basin, address asset, uint256 maxAmount, uint256 minConversionRate)
        external returns (uint256 assetsWithdrawn);
}

interface IBasinLike {
    function shares(address user) external view returns (uint256);
}

abstract contract BasinTestingBase is CommonPAUTestBase {

    bytes32 internal constant LIMIT_BASIN_DEPOSIT  = keccak256("LIMIT_BASIN_DEPOSIT");
    bytes32 internal constant LIMIT_BASIN_WITHDRAW = keccak256("LIMIT_BASIN_WITHDRAW");

    // Mirrors BasinFacet.getDepositRateLimitKey: makeAddressAddressKey(limit, asset, basin)
    function _basinDepositKey(address basin, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(LIMIT_BASIN_DEPOSIT, asset, basin));
    }

    function _basinWithdrawKey(address basin, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(LIMIT_BASIN_WITHDRAW, asset, basin));
    }

    function _testBasinOnboarding(
        address basin,
        address asset,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        PAUContext memory ctx = _getPAUContext();
        bool unlimitedDeposit = depositMax == type(uint256).max;

        address proxy = address(ctx.proxy);

        deal2(asset, proxy, expectedDepositAmount);

        bytes32 depositKey  = _basinDepositKey(basin, asset);
        bytes32 withdrawKey = _basinWithdrawKey(basin, asset);

        _assertPAUZeroRateLimit(depositKey);
        _assertPAUZeroRateLimit(withdrawKey);

        // Before the spell the deposit must revert: either the Basin
        // integration is not synced to the controller yet
        // (CallSelectorNotWired) or it is synced with no rate limit set
        // (RateLimits/zero-maxAmount).
        vm.expectRevert();
        _callAsPAUActor(abi.encodeCall(
            IBasinFacetLike.deposit,
            (basin, asset, expectedDepositAmount, 0)
        ));

        executeAllPayloadsAndBridges();

        _assertPAURateLimit(depositKey, depositMax, depositSlope);
        _assertPAUUnlimitedRateLimit(withdrawKey);

        if (!unlimitedDeposit) {
            vm.expectRevert("RateLimits/rate-limit-exceeded");
            _callAsPAUActor(abi.encodeCall(
                IBasinFacetLike.deposit,
                (basin, asset, depositMax + 1, 0)
            ));
        }

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  depositMax);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        uint256 startingShares = IBasinLike(basin).shares(proxy);

        _callAsPAUActor(abi.encodeCall(
            IBasinFacetLike.deposit,
            (basin, asset, expectedDepositAmount, 0)
        ));

        assertEq(IERC20(asset).balanceOf(proxy), 0);
        assertGt(IBasinLike(basin).shares(proxy), startingShares);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        _callAsPAUActor(abi.encodeCall(
            IBasinFacetLike.withdraw,
            (basin, asset, expectedDepositAmount / 2, 0)
        ));

        assertGe(IERC20(asset).balanceOf(proxy), expectedDepositAmount / 2);

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

}
