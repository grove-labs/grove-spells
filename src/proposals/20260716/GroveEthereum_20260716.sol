// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  July 16, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260716 is GrovePayloadEthereum {

    // TODO: placeholder (0xdeadbeef) Paxos USDC deposit wallet on Mainnet (Item 1c, Mainnet -> Robinhood).
    address internal constant PAXOS_USDC_DEPOSIT_WALLET = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

    constructor() {
        // TODO: deployed GroveRobinhood_20260716 address.
        PAYLOAD_ROBINHOOD = address(0);
    }

    function _execute() internal override {
        // [Ethereum] Item 1c (Mainnet -> Robinhood): Paxos USDC bridge rate limit.
        //   Forum : TODO
        _onboardPaxosUsdcBridgeRateLimit();
    }

    function _onboardPaxosUsdcBridgeRateLimit() internal {
        bytes32 transferKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            PAXOS_USDC_DEPOSIT_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            transferKey,
            50_000_000e6,                   // BEFORE: 0
            50_000_000e6 / uint256(1 days)  // BEFORE: 0
        );
    }

}
