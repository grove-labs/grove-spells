// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Base } from "lib/grove-address-registry/src/Base.sol";

import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }   from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { GrovePayloadBase } from "src/libraries/payloads/GrovePayloadBase.sol";

interface IRateLimitsLike {
    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;
}

/**
 * @title  November 19, 2026 Grove Base Proposal
 * @author Grove Labs
 */
contract GroveBase_20261119 is GrovePayloadBase {

    function execute() external {
        // [Base] Item 3: raise the Circle CCTP transfer rate limit to Ethereum.
        //   Forum : TODO
        _raiseCctpTransferRateLimitToEthereum();
    }

    function _raiseCctpTransferRateLimitToEthereum() internal {
        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        IRateLimitsLike(Base.ALM_RATE_LIMITS).setRateLimitData({
            key       : domainKey,
            maxAmount : 100_000_000e6,                   // BEFORE: 50_000_000e6
            slope     : 100_000_000e6 / uint256(1 days)  // BEFORE: 50_000_000e6 / 1 days
        });
    }

}
