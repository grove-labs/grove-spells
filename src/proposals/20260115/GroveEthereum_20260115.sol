// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { CastingHelpers } from "src/libraries/helpers/CastingHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  January 15, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260115 is GrovePayloadEthereum {

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {
        // [Base] Onboard Grove Liquidity Layer and CCTP for Base
        //   Forum : https://forum.sky.money/t/january-15th-2025-proposed-changes-to-grove-for-upcoming-spell/27570#p-105288-h-1-base-onboard-grove-liquidity-layer-and-cctp-for-base-2
        _onboardCctpTransfersToBase();
    }

    function _onboardCctpTransfersToBase() internal {
        // General key rate limit for all CCTP transfers was set in the GroveEthereum_20250807 proposal

        MainnetController(Ethereum.ALM_CONTROLLER).setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY)
        );

        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(domainKey, CCTP_RATE_LIMIT_MAX, CCTP_RATE_LIMIT_SLOPE);
    }

}
