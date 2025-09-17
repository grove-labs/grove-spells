// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }    from "lib/grove-address-registry/src/Plume.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { CastingHelpers } from "src/libraries/CastingHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

contract GroveEthereum_20250918 is GrovePayloadEthereum {

    address internal constant MAINNET_CENTRIFUGE_ACRDX_VAULT = 0x0000000000000000000000000000000000000000; // TODO: Add actual address

    uint256 internal constant ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                   // TODO: Add actual value
    uint256 internal constant ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 100_000_000e6 / uint256(1 days); // TODO: Add actual value
    uint256 internal constant ACRDX_DEPOSIT_RATE_LIMIT_MAX               = 20_000_000e6;                    // TODO: Add actual value
    uint256 internal constant ACRDX_DEPOSIT_RATE_LIMIT_SLOPE             = 20_000_000e6 / uint256(1 days);  // TODO: Add actual value
    uint256 internal constant CCTP_RATE_LIMIT_MAX                        = 50_000_000e6;                    // TODO: Add actual value
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE                      = 50_000_000e6 / uint256(1 days);  // TODO: Add actual value

    uint16 internal constant PLUME_DESTINATION_CENTRIFUGE_ID = 4;
    uint16 internal constant PLUME_DESTINATION_CCTP_ID       = 9999; // TODO: Add actual id

    function _execute() internal override {

        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _onboardCctpTransfersToPlume();

        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _onboardCentrifugeAcrdx();

        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _onboardCentrifugeAcrdxCrosschainTransfer();
    }

    function _onboardCctpTransfersToPlume() internal {
        bytes32 plumeCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            PLUME_DESTINATION_CCTP_ID
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : plumeCctpKey,
            maxAmount : CCTP_RATE_LIMIT_MAX,
            slope     : CCTP_RATE_LIMIT_SLOPE
        });

        MainnetController(Ethereum.ALM_CONTROLLER).setMintRecipient(
            PLUME_DESTINATION_CCTP_ID,
            CastingHelpers.addressToCctpRecipient(Plume.ALM_PROXY)
        );
    }

    function _onboardCentrifugeAcrdx() internal {
        _onboardERC7540Vault(
            MAINNET_CENTRIFUGE_ACRDX_VAULT,
            ACRDX_DEPOSIT_RATE_LIMIT_MAX,
            ACRDX_DEPOSIT_RATE_LIMIT_SLOPE
        );
    }

    function _onboardCentrifugeAcrdxCrosschainTransfer() internal {
        MainnetController(Ethereum.ALM_CONTROLLER).setCentrifugeRecipient(
            PLUME_DESTINATION_CENTRIFUGE_ID,
            CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY)
        );

        _setCentrifugeCrosschainTransferRateLimit(
            MAINNET_CENTRIFUGE_ACRDX_VAULT,
            PLUME_DESTINATION_CENTRIFUGE_ID,
            ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }
}
