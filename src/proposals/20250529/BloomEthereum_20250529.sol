// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, BloomPayloadEthereum } from "src/libraries/BloomPayloadEthereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/bloom-alm-controller/deploy/MainnetControllerInit.sol";

import { MainnetController } from "lib/bloom-alm-controller/src/MainnetController.sol";

/**
 * @title  May 29, 2025 Bloom Ethereum Proposal
 * @notice TODO: Add details
 * @author Steakhouse Financial
 * Forum: TODO: Add link
 * Vote:  TODO: Add link
 */
contract BloomEthereum_20250529 is BloomPayloadEthereum {

    address internal constant CENTRIFUGE_JTRSY_VAULT = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;

    function _execute() internal override {
        _onboardCentrifugeVault();
    }
    function _onboardCentrifugeVault() private {
        _onboardERC7540Vault(
            CENTRIFUGE_JTRSY_VAULT,
            100_000_000e6, // TODO: Get actual numbers
            50_000_000e6 / uint256(1 days)  // TODO: Get actual numbers
        );
    }

}
