// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  August 21, 2025 Grove Ethereum Proposal
 * @author Grove Labs
 * Forum : TODO
 * Vote  : TODO
 */
contract GroveEthereum_20250821 is GrovePayloadEthereum {

    constructor() {
        // TODO: Set Avalanche payload after deployment
        // PAYLOAD_AVALANCHE = 0x0000000000000000000000000000000000000000;
    }

    function _execute() internal override {
    }

}
