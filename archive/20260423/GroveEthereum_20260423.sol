// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { LZForwarder } from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { CastingHelpers }      from "src/libraries/helpers/CastingHelpers.sol";
import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  April 23, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260423 is GrovePayloadEthereum {

    address internal constant CENTRIFUGE_JTRSY_USDS = 0x381f4F3B43C30B78C1f7777553236e57bB8AE9ff;
    address internal constant USDS_OFT              = 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8;

    constructor() {
        PAYLOAD_AVALANCHE = 0x1204f2C342706cE6B75997c89619D130Ee9dDa2c;
    }

    function _execute() internal override {

        // [Ethereum] Increase USDS Mint Rate Limits
        //   Forum : https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829#p-106126-h-1-ethereum-increase-usds-mint-rate-limits-2
        _increaseUsdsMintRateLimit();
        // [Ethereum] Onboard USDS to Centrifuge JTRSY
        //   Forum : https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829#p-106126-h-2-ethereum-onboard-usds-to-centrifuge-jtrsy-8
        _onboardCentrifugeJtrsyUsds();

        // [Ethereum] Onboard USDS SkyLink Transfers to Avalanche
        //   Forum : https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829#p-106126-h-3-ethereum-onboard-usds-skylink-transfers-to-avalanche-14
        _onboardUsdsSkyLinkTransfersToAvalanche();
    }

    function _increaseUsdsMintRateLimit() internal {
        _setUSDSMintRateLimit({
            maxAmount : 500_000_000e18,                  // BEFORE: 100_000_000e18
            slope     : 500_000_000e18 / uint256(1 days) // BEFORE: 50_000_000e18/day
        });
    }

    function _onboardCentrifugeJtrsyUsds() internal {
        _onboardERC7540Vault({
            vault        : CENTRIFUGE_JTRSY_USDS,
            depositMax   : 500_000_000e18,                   // BEFORE: 0
            depositSlope : 500_000_000e18 / uint256(1 days)  // BEFORE: 0
        });
    }

    function _onboardUsdsSkyLinkTransfersToAvalanche() internal {
        MainnetController(Ethereum.ALM_CONTROLLER).setLayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_AVALANCHE,
            layerZeroRecipient    : CastingHelpers.addressToLayerZeroRecipient(Avalanche.ALM_PROXY)
        });

        bytes32 lzTransferKey = keccak256(abi.encode(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_LAYERZERO_TRANSFER(),
            USDS_OFT,
            LZForwarder.ENDPOINT_ID_AVALANCHE
        ));

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : lzTransferKey,
            maxAmount : 50_000_000e18,                  // BEFORE: 0
            slope     : 50_000_000e18 / uint256(1 days) // BEFORE: 0
        });
    }

}
