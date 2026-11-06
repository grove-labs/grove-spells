// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IRateLimitsLike {
    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;
}

/**
 * @title  November 19, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20261119 is GrovePayloadEthereum {

    address internal constant NEW_AGORA_AUSD_MINT   = 0xC6A7d3662e7d38f8e3a1e991116F6c3628bd7EDf;
    address internal constant NEW_AGORA_AUSD_REDEEM = 0x9307672C95c7B92e659da63EF5ee64B0C0D14619;

    constructor() {
        PAYLOAD_BASE = address(0); // TODO: set after foreign payload deploy
    }

    function _execute() internal override {
        // [Ethereum] Item 1 + Item 4: transfer the November 2026 grant and the GROVE purchase budget to the Grove Foundation.
        //   Forum : https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-grove-for-upcoming-spell/28387
        _transferUsdsToGroveFoundation();

        // [Ethereum] Item 2: add Agora's new AUSD mint and redeem addresses.
        //   Forum : https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-grove-for-upcoming-spell/28387
        _onboardNewAgoraAusdAddresses();

        // [Ethereum] Item 3: raise the Circle CCTP transfer rate limit to Base.
        //   Forum : https://forum.skyeco.com/t/november-19-2026-proposed-changes-to-grove-for-upcoming-spell/28387
        _raiseCctpTransferRateLimitToBase();

    }

    function _transferUsdsToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(Ethereum.GROVE_FOUNDATION, 1_100_000e18));
    }

    function _onboardNewAgoraAusdAddresses() internal {
        bytes32 mintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            NEW_AGORA_AUSD_MINT
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.AUSD,
            NEW_AGORA_AUSD_REDEEM
        );

        IRateLimitsLike(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : mintKey,
            maxAmount : 10_000_000e6,                    // BEFORE: 0
            slope     : 100_000_000e6 / uint256(1 days)  // BEFORE: 0
        });
        IRateLimitsLike(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : redeemKey,
            maxAmount : 10_000_000e6,                    // BEFORE: 0
            slope     : 100_000_000e6 / uint256(1 days)  // BEFORE: 0
        });
    }

    function _raiseCctpTransferRateLimitToBase() internal {
        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE
        );

        IRateLimitsLike(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : domainKey,
            maxAmount : 100_000_000e6,                   // BEFORE: 50_000_000e6
            slope     : 100_000_000e6 / uint256(1 days)  // BEFORE: 50_000_000e6 / 1 days
        });
    }

}
