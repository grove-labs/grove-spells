// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { CommonTestBase } from "../CommonTestBase.sol";

interface IGroveBasinLike {
    function pocket()                                          external view returns (address);
    function shares(address user)                              external view returns (uint256);
    function totalShares()                                     external view returns (uint256);
    function convertToAssets(address asset, uint256 numShares) external view returns (uint256);
    function withdraw(address asset, address receiver, uint256 maxAssetsToWithdraw)
        external returns (uint256 assetsWithdrawn);
}

abstract contract GroveBasinTestingBase is CommonTestBase {

    // End-to-end test of a Grove Basin onboarding item: exercises the spell-side initial USDS
    // deposit and confirms the basin is functional by round-tripping a withdrawal back to the
    // liquidity provider (Ethereum.ALM_PROXY).
    function _runInitialUsdsDepositToGroveBasinTest(address basinAddr, uint256 depositAmount) internal {
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
        uint256 assetsWithdrawn = basin.withdraw(Ethereum.USDS, Ethereum.ALM_PROXY, 1_000_000e18);

        // Step 4: verify the withdrawal round-trip — pocket released USDS, ALM_PROXY received
        // it, and the corresponding shares were burnt from both the holder and totalShares.
        assertEq(assetsWithdrawn, 1_000_000e18, "withdraw-returned-amount-mismatch");

        assertEq(
            usds.balanceOf(pocket),
            pocketUsdsBeforeWithdraw - 1_000_000e18,
            "pocket-usds-not-decreased-on-withdraw"
        );
        assertEq(
            usds.balanceOf(Ethereum.ALM_PROXY),
            almProxyUsdsBeforeWithdraw + 1_000_000e18,
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
            1_000_000e18,
            1,
            "burnt-shares-not-equivalent-to-withdrawn-amount"
        );
    }

}
