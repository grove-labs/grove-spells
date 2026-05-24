// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";

import { GrovePayloadAvalanche } from "src/libraries/payloads/GrovePayloadAvalanche.sol";

interface IExecutorLike {
    function SUBMISSION_ROLE() external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
}

/**
 * @title  June 4, 2026 Grove Avalanche Proposal
 * @author Grove Labs
 */
contract GroveAvalanche_20260604 is GrovePayloadAvalanche {

    address internal constant CCTP_V2_RECEIVER = 0x8Ea8Dff8c29f568eA1E716E2C3AfbD003EB83cfA;

    function execute() external {
        // [Avalanche] Onboard CCTP v2 Receiver
        //   Forum : TODO
        _onboardCctpV2Receiver();
    }

    function _onboardCctpV2Receiver() internal {
        IExecutorLike executor = IExecutorLike(Avalanche.GROVE_EXECUTOR);
        executor.grantRole(executor.SUBMISSION_ROLE(), CCTP_V2_RECEIVER);
    }

}
