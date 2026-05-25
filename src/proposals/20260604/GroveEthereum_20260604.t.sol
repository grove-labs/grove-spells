// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260604_Test is GroveTestBase {

    constructor() {
        id = "20260604";
    }

    function setUp() public {
        setupDomains("2026-05-22T11:00:00Z");
        deployPayloads();
    }

    function test_ETHEREUM_transferMonthlyGrantToGroveFoundation() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 foundationBalanceBefore = usds.balanceOf(Ethereum.GROVE_FOUNDATION);

        assertGe(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            1_600_000e18,
            "grove-proxy-insufficient-usds-balance"
        );

        executeAllPayloadsAndBridges();

        assertEq(
            usds.balanceOf(Ethereum.GROVE_FOUNDATION),
            foundationBalanceBefore + 1_600_000e18,
            "foundation-usds-balance-not-increased"
        );

        // The corresponding SubProxy USDS decrease is verified via the spell-wide USDS
        // conservation check in test_ETHEREUM_subProxyUsdsNetDelta(); it is omitted here
        // because Item 3 (PSM swap) also moves SubProxy USDS.
    }

    function test_ETHEREUM_transferGroveTokensToGroveFoundation() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 groveToken = IERC20(Ethereum.GROVE_TOKEN);

        uint256 foundationBalanceBefore = groveToken.balanceOf(Ethereum.GROVE_FOUNDATION);
        uint256 groveProxyBalanceBefore = groveToken.balanceOf(Ethereum.GROVE_PROXY);

        assertGe(
            groveProxyBalanceBefore,
            500_000_000e18,
            "grove-proxy-insufficient-grove-balance"
        );

        executeAllPayloadsAndBridges();

        uint256 foundationBalanceAfter = groveToken.balanceOf(Ethereum.GROVE_FOUNDATION);
        uint256 groveProxyBalanceAfter = groveToken.balanceOf(Ethereum.GROVE_PROXY);

        assertEq(
            foundationBalanceAfter,
            foundationBalanceBefore + 500_000_000e18,
            "foundation-grove-balance-not-increased"
        );
        assertEq(
            groveProxyBalanceAfter,
            groveProxyBalanceBefore - 500_000_000e18,
            "grove-proxy-grove-balance-not-decreased"
        );
    }

    function test_ETHEREUM_swapUsdcToUsdsViaPsm() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usdc = IERC20(Ethereum.USDC);

        uint256 subProxyUsdcBefore = usdc.balanceOf(Ethereum.GROVE_PROXY);

        assertGe(
            subProxyUsdcBefore,
            753_649e6,
            "grove-sub-proxy-insufficient-usdc-balance"
        );

        executeAllPayloadsAndBridges();

        assertEq(
            usdc.balanceOf(Ethereum.GROVE_PROXY),
            subProxyUsdcBefore - 753_649e6,
            "grove-sub-proxy-usdc-not-decreased"
        );
        assertEq(
            usdc.balanceOf(Ethereum.GROVE_PROXY),
            0,
            "grove-sub-proxy-usdc-not-fully-spent"
        );

        // The corresponding SubProxy USDS inflow from the PSM swap is verified via the
        // spell-wide USDS conservation check in test_ETHEREUM_subProxyUsdsNetDelta(); it is
        // omitted here because Item 1 (Foundation grant) also moves SubProxy USDS.
    }

    function test_ETHEREUM_subProxyUsdsNetDelta() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 subProxyUsdsBefore = usds.balanceOf(Ethereum.GROVE_PROXY);

        assertGe(
            subProxyUsdsBefore,
            1_600_000e18,
            "grove-proxy-insufficient-usds-balance"
        );

        executeAllPayloadsAndBridges();

        // Item 1 moves -1_600_000e18 USDS out of the SubProxy (Foundation grant).
        // Item 3 moves +753_649e18 USDS into the SubProxy (USDC -> USDS via the Sky PSM).
        // Net expected SubProxy USDS delta = -1_600_000e18 + 753_649e18 = -846_351e18.
        assertEq(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            subProxyUsdsBefore + 753_649e18 - 1_600_000e18,
            "grove-sub-proxy-usds-net-delta-mismatch"
        );
    }

}
