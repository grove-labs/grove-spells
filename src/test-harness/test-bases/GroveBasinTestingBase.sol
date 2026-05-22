// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Math } from "lib/xchain-helpers/lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { CommonTestBase } from "../CommonTestBase.sol";

interface IGroveBasinLike {
    function BPS()                                             external view returns (uint256);
    function pocket()                                          external view returns (address);
    function creditToken()                                     external view returns (address);
    function swapToken()                                       external view returns (address);
    function collateralToken()                                 external view returns (address);
    function creditTokenRateProvider()                         external view returns (address);
    function swapTokenRateProvider()                           external view returns (address);
    function collateralTokenRateProvider()                     external view returns (address);
    function redemptionFee()                                   external view returns (uint256);
    function shares(address user)                              external view returns (uint256);
    function totalShares()                                     external view returns (uint256);
    function convertToAssets(address asset, uint256 numShares) external view returns (uint256);

    function withdraw(address asset, address receiver, uint256 maxAssetsToWithdraw)
        external returns (uint256 assetsWithdrawn);

    function previewSwapExactIn(address fromAsset, address toAsset, uint256 amountIn)
        external view returns (uint256);
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);
}

interface IGroveRateProviderLike {
    function getConversionRate() external view returns (uint256);
    function getRatePrecision()  external view returns (uint256);
}

abstract contract GroveBasinTestingBase is CommonTestBase {

    // End-to-end test of a Grove Basin onboarding item: exercises the spell-side initial USDS
    // deposit and confirms the basin is functional by round-tripping a withdrawal back to the
    // liquidity provider (Ethereum.ALM_PROXY).
    function _runInitialUsdsDepositToGroveBasinTest(
        address basinAddr,
        uint256 depositAmount,
        uint256 withdrawAmount
    ) internal {
        require(withdrawAmount <= depositAmount, "withdraw-amount-exceeds-deposit");

        IGroveBasinLike basin  = IGroveBasinLike(basinAddr);
        IERC20          usds   = IERC20(Ethereum.USDS);
        address         pocket = basin.pocket();

        // Step 1: snapshot pre-spell state and execute the spell. The spell grants itself the
        // CONTROLLER role on ALM_PROXY, draws `depositAmount` USDS from the Allocator, and
        // calls basin.deposit(USDS, ALM_PROXY, depositAmount).
        uint256 pocketUsdsBefore     = usds.balanceOf(pocket);
        uint256 almProxySharesBefore = basin.shares(Ethereum.ALM_PROXY);

        executeAllPayloadsAndBridges();

        // Step 2: verify the initial deposit landed — USDS sits in the pocket and ALM_PROXY
        // received shares whose USDS equivalent matches the deposit (1 wei tolerance for any
        // share-price rounding).
        assertEq(
            usds.balanceOf(pocket),
            pocketUsdsBefore + depositAmount,
            "pocket-usds-balance-not-increased"
        );

        uint256 sharesMinted = basin.shares(Ethereum.ALM_PROXY) - almProxySharesBefore;
        assertGt(sharesMinted, 0, "alm-proxy-not-minted-shares");
        assertApproxEqAbs(
            basin.convertToAssets(Ethereum.USDS, sharesMinted),
            depositAmount,
            1,
            "minted-shares-not-equivalent-to-deposit"
        );

        // Step 3: snapshot pre-withdrawal state and exercise basin.withdraw() as the LP
        // (Ethereum.ALM_PROXY) to prove the deposited liquidity is actually retrievable.
        uint256 pocketUsdsBeforeWithdraw     = usds.balanceOf(pocket);
        uint256 almProxyUsdsBeforeWithdraw   = usds.balanceOf(Ethereum.ALM_PROXY);
        uint256 almProxySharesBeforeWithdraw = basin.shares(Ethereum.ALM_PROXY);
        uint256 totalSharesBeforeWithdraw    = basin.totalShares();

        vm.prank(Ethereum.ALM_PROXY);
        uint256 assetsWithdrawn = basin.withdraw(Ethereum.USDS, Ethereum.ALM_PROXY, withdrawAmount);

        // Step 4: verify the withdrawal round-trip — pocket released USDS, ALM_PROXY received
        // the same amount, and the corresponding shares were burnt from both the holder and
        // totalShares. The basin may return slightly less than the requested amount due to
        // share-price rounding, so we accept a 1-wei tolerance and pivot all subsequent
        // assertions on the actual `assetsWithdrawn`.
        assertApproxEqAbs(
            assetsWithdrawn,
            withdrawAmount,
            1,
            "withdraw-returned-amount-mismatch"
        );

        assertEq(
            usds.balanceOf(pocket),
            pocketUsdsBeforeWithdraw - assetsWithdrawn,
            "pocket-usds-not-decreased-on-withdraw"
        );
        assertEq(
            usds.balanceOf(Ethereum.ALM_PROXY),
            almProxyUsdsBeforeWithdraw + assetsWithdrawn,
            "alm-proxy-usds-not-increased-on-withdraw"
        );

        uint256 sharesBurnt = almProxySharesBeforeWithdraw - basin.shares(Ethereum.ALM_PROXY);
        assertGt(sharesBurnt, 0, "alm-proxy-shares-not-burnt");
        assertEq(
            totalSharesBeforeWithdraw - basin.totalShares(),
            sharesBurnt,
            "total-shares-not-decremented-by-burnt-amount"
        );
        assertApproxEqAbs(
            basin.convertToAssets(Ethereum.USDS, sharesBurnt),
            assetsWithdrawn,
            1,
            "burnt-shares-not-equivalent-to-withdrawn-amount"
        );
    }

    // Confirms the Grove Basin is operational after the spell executes by exercising both
    // outflow directions available to users for issuer-mediated credit tokens (no admin pranks
    // or extra liquidity seeding required):
    //   1. user1 sells credit token, receives USDS.
    //   2. user2 sells credit token, receives USDC.
    // The expected output for each leg is independently derived from the basin's rate providers
    // and redemption fee — the test does not trust `previewSwapExactIn` as ground truth.
    function _runGroveBasinSwapTest(address basinAddr, uint256 amountIn) internal {
        IGroveBasinLike basin       = IGroveBasinLike(basinAddr);
        address         creditToken = basin.creditToken();

        executeAllPayloadsAndBridges();

        uint256 expectedUsdsOut = _expectedGroveBasinSwapOut(basin, creditToken, Ethereum.USDS, amountIn);
        assertGt(expectedUsdsOut, 0, "credit-to-usds-expected-zero");
        assertEq(
            basin.previewSwapExactIn(creditToken, Ethereum.USDS, amountIn),
            expectedUsdsOut,
            "credit-to-usds-preview-vs-oracle-mismatch"
        );

        address user1 = makeAddr("groveBasinUser1");
        deal2(creditToken, user1, amountIn);

        vm.startPrank(user1);
        IERC20(creditToken).approve(basinAddr, amountIn);
        uint256 usdsOut = basin.swapExactIn(creditToken, Ethereum.USDS, amountIn, expectedUsdsOut, user1, 0);
        vm.stopPrank();

        assertEq(usdsOut, expectedUsdsOut, "credit-to-usds-amount-out-mismatch");
        assertEq(IERC20(Ethereum.USDS).balanceOf(user1), usdsOut, "user1-usds-balance-mismatch");

        uint256 expectedUsdcOut = _expectedGroveBasinSwapOut(basin, creditToken, Ethereum.USDC, amountIn);
        assertGt(expectedUsdcOut, 0, "credit-to-usdc-expected-zero");
        assertEq(
            basin.previewSwapExactIn(creditToken, Ethereum.USDC, amountIn),
            expectedUsdcOut,
            "credit-to-usdc-preview-vs-oracle-mismatch"
        );

        address user2 = makeAddr("groveBasinUser2");
        deal2(creditToken, user2, amountIn);

        vm.startPrank(user2);
        IERC20(creditToken).approve(basinAddr, amountIn);
        uint256 usdcOut = basin.swapExactIn(creditToken, Ethereum.USDC, amountIn, expectedUsdcOut, user2, 0);
        vm.stopPrank();

        assertEq(usdcOut, expectedUsdcOut, "credit-to-usdc-amount-out-mismatch");
        assertEq(IERC20(Ethereum.USDC).balanceOf(user2), usdcOut, "user2-usdc-balance-mismatch");
    }

    // Replicates the basin's `previewSwapExactIn` formula for credit → non-credit swaps using
    // oracle data only:
    //   grossOut    = _convert(amountIn, rateIn, ratePrecisionIn, tokenPrecisionIn,
    //                                    rateOut, ratePrecisionOut, tokenPrecisionOut, false)
    //   redemption  = ceilDiv(grossOut * redemptionFee, BPS)
    //   amountOut   = grossOut - redemption
    function _expectedGroveBasinSwapOut(
        IGroveBasinLike basin,
        address         assetIn,
        address         assetOut,
        uint256         amountIn
    ) internal view returns (uint256) {
        uint256 grossOut = _basinGrossSwapQuote(basin, assetIn, assetOut, amountIn);
        uint256 fee      = Math.ceilDiv(grossOut * basin.redemptionFee(), basin.BPS());

        return grossOut - fee;
    }

    function _basinGrossSwapQuote(
        IGroveBasinLike basin,
        address         assetIn,
        address         assetOut,
        uint256         amountIn
    ) internal view returns (uint256) {
        (uint256 rIn,  uint256 rpIn,  uint256 tpIn ) = _basinAssetRateAndPrecision(basin, assetIn);
        (uint256 rOut, uint256 rpOut, uint256 tpOut) = _basinAssetRateAndPrecision(basin, assetOut);

        uint256 numeratorPrecision   = tpOut * rpOut;
        uint256 denominatorPrecision = tpIn  * rpIn;

        if (numeratorPrecision >= denominatorPrecision) {
            return Math.mulDiv(amountIn, rIn * (numeratorPrecision / denominatorPrecision), rOut);
        }
        return Math.mulDiv(amountIn, rIn, rOut * (denominatorPrecision / numeratorPrecision));
    }

    function _basinAssetRateAndPrecision(IGroveBasinLike basin, address token)
        internal view returns (uint256 rate, uint256 ratePrecision, uint256 tokenPrecision)
    {
        address rateProvider;
        if      (token == basin.swapToken())       rateProvider = basin.swapTokenRateProvider();
        else if (token == basin.collateralToken()) rateProvider = basin.collateralTokenRateProvider();
        else if (token == basin.creditToken())     rateProvider = basin.creditTokenRateProvider();
        else                                       revert("invalid-basin-asset");

        rate           = IGroveRateProviderLike(rateProvider).getConversionRate();
        ratePrecision  = IGroveRateProviderLike(rateProvider).getRatePrecision();
        tokenPrecision = 10 ** IERC20(token).decimals();
    }

}
