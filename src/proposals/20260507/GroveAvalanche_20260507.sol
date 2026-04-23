// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IExecutor } from "lib/grove-gov-relay/src/interfaces/IExecutor.sol";

import { GrovePayloadAvalanche } from "src/libraries/payloads/GrovePayloadAvalanche.sol";

/**
 * @title  May 7, 2026 Grove Avalanche Proposal
 * @author Grove Labs
 */
contract GroveAvalanche_20260507 is GrovePayloadAvalanche {

    address internal constant NEW_LZ_RECEIVER   = 0x380Be2b91B63BF75B194913b6e2C07Df09598c22;

    function execute() external {
        // [Avalanche] Upgrade Governance Relay to LayerZero V2
        //   Forum : TODO: Add forum link
        _upgradeGovernanceRelayToLayerZeroV2();
    }

    function _upgradeGovernanceRelayToLayerZeroV2() internal {
        IExecutor executor = IExecutor(address(this));

        bytes32 submissionRole = executor.SUBMISSION_ROLE();

        executor.grantRole(submissionRole, NEW_LZ_RECEIVER);
    }

}
