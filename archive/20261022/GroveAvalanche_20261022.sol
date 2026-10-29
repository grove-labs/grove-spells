// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";

import { GrovePayloadAvalanche } from "src/libraries/payloads/GrovePayloadAvalanche.sol";

interface IExecutorLike {
    function SUBMISSION_ROLE() external view returns (bytes32);
    function revokeRole(bytes32 role, address account) external;
}

/**
 * @title  October 22, 2026 Grove Avalanche Proposal
 * @author Grove Labs
 */
contract GroveAvalanche_20261022 is GrovePayloadAvalanche {

    function execute() external {
        // [Avalanche] Item 2: revoke the Circle CCTP v1 Governance Relay Receiver's submission role on the Grove Executor.
        //   Forum : https://forum.skyeco.com/t/october-22-2026-proposed-changes-to-grove-for-upcoming-spell/28296/2
        _offboardCctpV1Receiver();
    }

    function _offboardCctpV1Receiver() internal {
        IExecutorLike executor = IExecutorLike(Avalanche.GROVE_EXECUTOR);
        executor.revokeRole(executor.SUBMISSION_ROLE(), Avalanche.GROVE_CCTP_V1_RECEIVER);
    }

}
