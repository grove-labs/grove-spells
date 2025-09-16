// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

contract GroveEthereum_20250918 is GrovePayloadEthereum {

    address internal constant MAINNET_CENTRIFUGE_ACRDX_VAULT = 0x0000000000000000000000000000000000000000; // TODO: Add actual address

    uint256 internal constant ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                   // TODO: Add actual value
    uint256 internal constant ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 100_000_000e6 / uint256(1 days); // TODO: Add actual value

    uint16 internal constant PLUME_DESTINATION_CENTRIFUGE_ID = 9999; // TODO: Add actual value

    function _execute() internal override {
        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _onboardCentrifugeAcrdxCrosschainTransfer();
    }

    function _onboardCentrifugeAcrdxCrosschainTransfer() internal {
        _setCentrifugeCrosschainTransferRateLimit(
            MAINNET_CENTRIFUGE_ACRDX_VAULT,
            PLUME_DESTINATION_CENTRIFUGE_ID,
            ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }
}
