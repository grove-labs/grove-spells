// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }    from "lib/grove-address-registry/src/Plume.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { CastingHelpers }       from "src/libraries/CastingHelpers.sol";
import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

contract GroveEthereum_20250918 is GrovePayloadEthereum {

    uint256 internal constant JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 20_000_000e6;
    uint256 internal constant JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint16 internal constant PLUME_DESTINATION_CENTRIFUGE_ID = 4;

    function _execute() internal override {
        // TODO: Add item title
        //   Forum : https://forum.sky.money/t/october-2-2025-proposed-changes-to-grove-for-upcoming-spell/27190
        //   Poll  : TODO: Add link
        _onboardCentrifugeJtrsyCrosschainTransfer();
    }

    function _onboardCentrifugeJtrsyCrosschainTransfer() internal {
        MainnetController(Ethereum.ALM_CONTROLLER).setCentrifugeRecipient(
            PLUME_DESTINATION_CENTRIFUGE_ID,
            CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY)
        );

        _setCentrifugeCrosschainTransferRateLimit(
            Ethereum.CENTRIFUGE_JTRSY,
            PLUME_DESTINATION_CENTRIFUGE_ID,
            JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }

}
