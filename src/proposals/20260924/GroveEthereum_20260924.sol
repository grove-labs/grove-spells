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

    address internal constant BUIDLI_GROVE_BASIN = 0xf1615aC3181a4a28D35fB2b9cea84dd4a199B9D7;

    constructor() {
        PAYLOAD_BASE = address(0); // TODO: set after foreign payload deploy
    }

    function _execute() internal override {
        // [Ethereum] Item 1: Treasury Distribution of 800,000 USDS to the Grove Foundation Multisig.
        //   Forum : https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-grove-for-upcoming-spell/28229
        _treasuryDistributionToGroveFoundation();

        // [Ethereum] Item 3: onboard the BUIDL-I Tokenized Treasury (Basin) Instance on the Grove PAU.
        //   Forum : https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-grove-for-upcoming-spell/28229
        _onboardBuidlIBasin();

        // [Ethereum] Item 4: set the Grove PAU unwind rate limits to unlimited.
        //   Forum : https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-grove-for-upcoming-spell/28229
        _setPauUnwindRateLimitsToUnlimited();
    }

    function _treasuryDistributionToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(Ethereum.GROVE_FOUNDATION, 800_000e18));
    }

    function _onboardBuidlIBasin() internal {
        _setBasinPauRateLimits({
            rateLimits   : Ethereum.PAU_RATE_LIMITS,
            basin        : BUIDLI_GROVE_BASIN,
            depositMax   : 5_000_000e18,                  // BEFORE: 0
            depositSlope : 5_000_000e18 / uint256(1 days) // BEFORE: 0
        //  withdrawDepositAssetMax      : unlimited         BEFORE: 0
        //  withdrawDepositAssetSlope    : 0                 BEFORE: 0
        //  withdrawCollateralAssetMax   : unlimited         BEFORE: 0
        //  withdrawCollateralAssetSlope : 0                 BEFORE: 0
        });
    }

    function _setPauUnwindRateLimitsToUnlimited() internal {
        // Set key-by-key instead of through _setUsdsMintBurnPauRateLimits / _setPsmSwapPauRateLimits:
        // each of those writes both directions of its pair, which would also rewrite the outbound
        // mint and USDS->USDC keys that this item must leave untouched.
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setUnlimitedRateLimitData(
            GrovePauHelpers.LIMIT_USDS_BURN     // BEFORE: 14_929_920e18 max ; 14_929_920e18 / 1 days slope
        );
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setUnlimitedRateLimitData(
            GrovePauHelpers.LIMIT_USDC_TO_USDS  // BEFORE: 14_929_920e6 max ; 14_929_920e6 / 1 days slope
        );
    }

}
