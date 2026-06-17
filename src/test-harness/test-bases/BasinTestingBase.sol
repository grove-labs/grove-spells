// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { IPAUBaseControllerLike, PAUContext, CommonPAUTestBase } from "../CommonPAUTestBase.sol";

// The controller dispatches namespaced call selectors (basin_*) to the
// BasinFacet's internal deposit/withdraw delegate selectors, so callers
// must encode the namespaced form (see IMainnetControllerFull in diamond-pau).
// Inherits the shared USDS mint/burn + PSM swap entrypoints (IPAUBaseControllerLike)
// the basin lifecycle also drives directly.
interface IBasinControllerLike is IPAUBaseControllerLike {
    function basin_deposit(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external returns (uint256 shares);
    function basin_withdraw(address basin, address asset, uint256 maxAmount, uint256 minConversionRate)
        external returns (uint256 assetsWithdrawn);
}

interface IBasinLike {
    function shares(address user) external view returns (uint256);
    function pocket() external view returns (address);
}

abstract contract BasinTestingBase is CommonPAUTestBase {

    bytes32 internal constant LIMIT_BASIN_DEPOSIT  = keccak256("LIMIT_BASIN_DEPOSIT");
    bytes32 internal constant LIMIT_BASIN_WITHDRAW = keccak256("LIMIT_BASIN_WITHDRAW");

    function _basinDepositKey(address basin, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(LIMIT_BASIN_DEPOSIT, asset, basin));
    }

    function _basinWithdrawKey(address basin, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(LIMIT_BASIN_WITHDRAW, asset, basin));
    }

    function _testBasinOnboarding(
        address basin,
        address swapToken,
        address collateralToken,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        PAUContext memory ctx = _getPAUContext();

        bytes32 depositKey            = _basinDepositKey(basin, swapToken);
        bytes32 withdrawKey           = _basinWithdrawKey(basin, swapToken);
        bytes32 collateralWithdrawKey = _basinWithdrawKey(basin, collateralToken);

        // --- Before the spell: deposit + both withdraw limits unset, and deposits are gated. ---
        _assertPAUZeroRateLimit(depositKey);
        _assertPAUZeroRateLimit(withdrawKey);
        _assertPAUZeroRateLimit(collateralWithdrawKey);

        deal2(swapToken, address(ctx.proxy), expectedDepositAmount);

        // Derive the concrete revert reason from onchain state so a wrong revert (e.g. a selector
        // typo) cannot slip through a catch-all expectRevert.
        bytes4 depositSelector = IBasinControllerLike.basin_deposit.selector;
        if (IPAUBaseControllerLike(ctx.controller).getDispatch(depositSelector).facet == address(0)) {
            vm.expectRevert(abi.encodeWithSignature("CallSelectorNotWired(bytes4)", depositSelector));
        } else if (!ctx.accessControls.hasRole(ALLOCATOR_ROLE, ctx.agent)) {
            vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", ctx.agent, ALLOCATOR_ROLE));
        } else {
            vm.expectRevert("RateLimits/zero-maxAmount");
        }
        _callAsPAUActor(ctx, abi.encodeCall(
            IBasinControllerLike.basin_deposit,
            (basin, swapToken, expectedDepositAmount, 0)
        ));

        executeAllPayloadsAndBridges();

        // --- After the spell: deposit limit set; both USDS + USDC withdraws unlimited. ---
        _assertPAURateLimit(depositKey, depositMax, depositSlope);
        _assertPAUUnlimitedRateLimit(withdrawKey);
        _assertPAUUnlimitedRateLimit(collateralWithdrawKey);

        // Deposits above the cap revert.
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        _callAsPAUActor(ctx, abi.encodeCall(
            IBasinControllerLike.basin_deposit,
            (basin, swapToken, depositMax + 1, 0)
        ));

        // --- Whole flow: mint -> deposit -> swap + redemption -> withdraw collateral -> PSM -> burn. ---
        _runBasinLifecycle(ctx, basin, swapToken, collateralToken, expectedDepositAmount, depositMax);

        // --- Deposit-limit slope sanity (recharges to max in >= 1 day and <= 30 days). ---
        assertLe(depositSlope * 1 days,  depositMax, "basin-slope-too-fast");
        assertGe(depositSlope * 30 days, depositMax, "basin-slope-too-slow");
    }

    /// @dev mint -> deposit -> simulated swap + redemption -> withdraw collateral -> PSM swap -> burn
    function _runBasinLifecycle(
        PAUContext memory ctx,
        address basin,
        address swapToken,
        address collateralToken,
        uint256 amount,
        uint256 depositMax
    ) private {
        address proxy = address(ctx.proxy);

        uint256 proxySwapTokenStart       = IERC20(swapToken).balanceOf(proxy);
        uint256 proxyCollateralTokenStart = IERC20(collateralToken).balanceOf(proxy);

        // 1. Mint USDS through Sky's ALLOCATOR-GROVE-A instance.
        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.usds_mint, (amount)));
        assertEq(IERC20(swapToken).balanceOf(proxy), proxySwapTokenStart + amount, "basin-lifecycle-mint");

        // 2. Deposit the minted USDS into the basin (pocket gains USDS, proxy gains shares).
        {
            uint256 sharesBefore = IBasinLike(basin).shares(proxy);
            _callAsPAUActor(ctx, abi.encodeCall(IBasinControllerLike.basin_deposit, (basin, swapToken, amount, 0)));
            assertEq(IERC20(swapToken).balanceOf(proxy), proxySwapTokenStart, "basin-lifecycle-deposit-spent");
            assertGt(IBasinLike(basin).shares(proxy),    sharesBefore,        "basin-lifecycle-deposit-shares");
            assertEq(ctx.rateLimits.getCurrentRateLimit(_basinDepositKey(basin, swapToken)), depositMax - amount, "basin-lifecycle-deposit-limit");
        }

        // 3. Simulate the credit-token swap (pocket pays out USDS) + its redemption to USDC at par
        //    (basin, the collateral custodian, receives USDC). USDS is 18dp, USDC is 6dp.
        uint256 redeemedCollateral = (amount / 2) / _collateralScale(swapToken, collateralToken);
        {
            address pocket = IBasinLike(basin).pocket();
            deal2(swapToken,       pocket, IERC20(swapToken).balanceOf(pocket) - amount / 2);
            deal2(collateralToken, basin,  IERC20(collateralToken).balanceOf(basin) + redeemedCollateral);
        }

        // 4. Withdraw the redeemed USDC (exercises the USDC withdraw limit this spell adds).
        bytes memory withdrawReturn = _callAsPAUActor(ctx, abi.encodeCall(IBasinControllerLike.basin_withdraw, (basin, collateralToken, redeemedCollateral, 0)));
        uint256 collateralOut = abi.decode(withdrawReturn, (uint256));
        assertEq(collateralOut, redeemedCollateral, "basin-lifecycle-withdraw");
        assertEq(IERC20(collateralToken).balanceOf(proxy) - proxyCollateralTokenStart, collateralOut, "basin-lifecycle-withdraw-balance");
        assertEq(ctx.rateLimits.getCurrentRateLimit(_basinWithdrawKey(basin, collateralToken)), type(uint256).max, "basin-lifecycle-withdraw-unlimited");

        // 5. Swap the withdrawn USDC back to USDS through the PSM (0 fee).
        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.psm_swapUSDCToUSDS, (collateralOut)));
        assertEq(IERC20(collateralToken).balanceOf(proxy), proxyCollateralTokenStart,                  "basin-lifecycle-psm-collateral");
        assertEq(IERC20(swapToken).balanceOf(proxy),       proxySwapTokenStart + collateralOut * _collateralScale(swapToken, collateralToken), "basin-lifecycle-psm-asset");

        // 6. Burn the round-tripped USDS, closing out the position.
        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.usds_burn, (collateralOut * _collateralScale(swapToken, collateralToken))));
        assertEq(IERC20(swapToken).balanceOf(proxy), proxySwapTokenStart, "basin-lifecycle-burn");
    }

    /// @dev Scale between the swap-leg (e.g. USDS, 18dp) and collateral-leg (e.g. USDC, 6dp) decimal bases.
    function _collateralScale(address swapToken, address collateralToken) private view returns (uint256) {
        return 10 ** (IERC20(swapToken).decimals() - IERC20(collateralToken).decimals());
    }

}
