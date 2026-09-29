// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { IRateLimits as IPauRateLimits } from "diamond-pau/interfaces/IRateLimits.sol";

import { GrovePauHelpers } from "src/libraries/helpers/GrovePauHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}

/**
 * @title  September 24, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260924 is GrovePayloadEthereum {

    constructor() {
        PAYLOAD_BASE = 0xd3642d91279c58508E9986b8742Ac51eb70BF72e;
    }

    function _execute() internal override {
        // [Ethereum] Item 1: Treasury Distribution of 800,000 USDS to the Grove Foundation Multisig.
        //   Forum : https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-grove-for-upcoming-spell/28229
        _treasuryDistributionToGroveFoundation();

        // [Ethereum] Item 3: set the Grove PAU unwind rate limits to unlimited.
        //   Forum : https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-grove-for-upcoming-spell/28229
        _setPauUnwindRateLimitsToUnlimited();
    }

    function _treasuryDistributionToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(Ethereum.GROVE_FOUNDATION, 800_000e18));
    }

    function _setPauUnwindRateLimitsToUnlimited() internal {
        // Set key-by-key instead of through _setUsdsMintBurnPauRateLimits / _setPsmSwapPauRateLimits:
        // each of those writes both directions of its pair, which would also rewrite the outbound
        // mint and USDS->USDC keys that this item must leave untouched.
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setUnlimitedRateLimitData(
            GrovePauHelpers.LIMIT_USDS_BURN     // BEFORE: 15_000_000e18 max ; 17_915_904e18 / 1 days slope (read 2026-09-11)
        );
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setUnlimitedRateLimitData(
            GrovePauHelpers.LIMIT_USDC_TO_USDS  // BEFORE: 15_000_000e6 max ; 17_915_904e6 / 1 days slope (read 2026-09-11)
        );
    }

}
