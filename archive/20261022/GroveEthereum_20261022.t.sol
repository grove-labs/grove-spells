// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IExecutor } from "lib/grove-gov-relay/src/interfaces/IExecutor.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20261022_Test is GroveTestBase {

    address internal constant PAYLOAD_ETHEREUM  = 0xf9449D21ef687eE55233B9EDC3d7DDA87C7562a7;
    address internal constant PAYLOAD_AVALANCHE = 0xA6098Ee0248ce604bC057dFc62C7eFBc77699F6B;

    constructor() {
        id = "20261022";
    }

    function setUp() public {
        setupDomains("2026-10-13T10:29:35Z");

        chainData[ChainIdUtils.Ethereum()].payload  = PAYLOAD_ETHEREUM;
        chainData[ChainIdUtils.Avalanche()].payload = PAYLOAD_AVALANCHE;
    }

    function test_ETHEREUM_treasuryDistributionToGroveFoundation() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 subProxyUsdsStart   = usds.balanceOf(Ethereum.GROVE_PROXY);
        uint256 foundationUsdsStart = usds.balanceOf(Ethereum.GROVE_FOUNDATION);

        assertGe(subProxyUsdsStart, 800_000e18, "grove-proxy-insufficient-usds-balance");

        executeAllPayloadsAndBridges();

        assertEq(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            subProxyUsdsStart - 800_000e18,
            "grove-proxy-usds-not-decreased"
        );

        assertEq(
            usds.balanceOf(Ethereum.GROVE_FOUNDATION),
            foundationUsdsStart + 800_000e18,
            "foundation-usds-balance-not-increased"
        );
    }

    function test_AVALANCHE_offboardCctpV1Receiver() public onChain(ChainIdUtils.Avalanche()) {
        IExecutor executor       = IExecutor(Avalanche.GROVE_EXECUTOR);
        bytes32   submissionRole = executor.SUBMISSION_ROLE();

        assertTrue(
            executor.hasRole(submissionRole, Avalanche.GROVE_CCTP_V1_RECEIVER),
            "cctpv1-receiver-missing-submission-role-before"
        );
        assertTrue(
            executor.hasRole(submissionRole, Avalanche.GROVE_CCTP_V2_RECEIVER),
            "cctpv2-receiver-missing-submission-role-before"
        );

        executeAllPayloadsAndBridges();

        assertFalse(
            executor.hasRole(submissionRole, Avalanche.GROVE_CCTP_V1_RECEIVER),
            "cctpv1-receiver-still-has-submission-role"
        );
        assertTrue(
            executor.hasRole(submissionRole, Avalanche.GROVE_CCTP_V2_RECEIVER),
            "cctpv2-receiver-lost-submission-role"
        );
    }

}
