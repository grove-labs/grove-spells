// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}

/**
 * @title  October 22, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20261022 is GrovePayloadEthereum {

    constructor() {
        PAYLOAD_AVALANCHE = 0xA6098Ee0248ce604bC057dFc62C7eFBc77699F6B;
    }

    function _execute() internal override {
        // [Ethereum] Item 1: Treasury Distribution of 800,000 USDS to the Grove Foundation Multisig.
        //   Forum : https://forum.skyeco.com/t/october-22-2026-proposed-changes-to-grove-for-upcoming-spell/28296/2
        _treasuryDistributionToGroveFoundation();
    }

    function _treasuryDistributionToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(Ethereum.GROVE_FOUNDATION, 800_000e18));
    }

}
