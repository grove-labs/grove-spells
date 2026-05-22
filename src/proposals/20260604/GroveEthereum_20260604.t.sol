// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Vm }     from "forge-std/Vm.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { IALMProxy } from "grove-alm-controller/src/interfaces/IALMProxy.sol";

import { RecordedLogs } from "xchain-helpers/testing/utils/RecordedLogs.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260604_Test is GroveTestBase {

    address internal constant JTRSY_GROVE_BASIN = 0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363;
    address internal constant BUIDL_GROVE_BASIN = 0x10b3d3A96646720f8B3a29229cF96d513f3C84F1;

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

    function test_ETHEREUM_depositInitialUsdsToJtrsyGroveBasin() public onChain(ChainIdUtils.Ethereum()) {
        _runInitialUsdsDepositToGroveBasinTest({
            basinAddr      : JTRSY_GROVE_BASIN,
            depositAmount  : 50_000_000e18,
            withdrawAmount : 1_000_000e18
        });
    }

    function test_ETHEREUM_depositInitialUsdsToBuidlGroveBasin() public onChain(ChainIdUtils.Ethereum()) {
        _runInitialUsdsDepositToGroveBasinTest({
            basinAddr      : BUIDL_GROVE_BASIN,
            depositAmount  : 50_000_000e18,
            withdrawAmount : 1_000_000e18
        });
    }

    function test_ETHEREUM_e2eJtrsyGroveBasin() public onChain(ChainIdUtils.Ethereum()) {
        _runGroveBasinSwapTest({
            basinAddr : JTRSY_GROVE_BASIN,
            amountIn  : 100e6
        });
    }

    function test_ETHEREUM_e2eBuidlGroveBasin() public onChain(ChainIdUtils.Ethereum()) {
        _runGroveBasinSwapTest({
            basinAddr : BUIDL_GROVE_BASIN,
            amountIn  : 100e6
        });
    }

    function test_ETHEREUM_almProxyControllerRoleGrantedToGroveProxyDuringSpell() public onChain(ChainIdUtils.Ethereum()) {
        IALMProxy almProxy       = IALMProxy(Ethereum.ALM_PROXY);
        bytes32   controllerRole = almProxy.CONTROLLER();

        assertFalse(
            almProxy.hasRole(controllerRole, Ethereum.GROVE_PROXY),
            "grove-proxy-holds-controller-role-before-spell"
        );

        executeAllPayloadsAndBridges();

        bytes32 roleGrantedTopic = keccak256("RoleGranted(bytes32,address,address)");
        bytes32 groveProxyTopic  = bytes32(uint256(uint160(Ethereum.GROVE_PROXY)));

        Vm.Log[] memory logs = RecordedLogs.getLogs();

        bool seenGrantToGroveProxy;
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.emitter != Ethereum.ALM_PROXY)   continue;
            if (log.topics.length < 4)               continue;
            if (log.topics[0] != roleGrantedTopic)   continue;
            if (log.topics[1] != controllerRole)     continue;
            if (log.topics[2] != groveProxyTopic)    continue;

            seenGrantToGroveProxy = true;
            break;
        }

        assertTrue(
            seenGrantToGroveProxy,
            "controller-role-not-granted-to-grove-proxy-during-spell"
        );

        assertFalse(
            almProxy.hasRole(controllerRole, Ethereum.GROVE_PROXY),
            "grove-proxy-retained-controller-role-after-spell"
        );
    }

}
