// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }    from "lib/grove-address-registry/src/Plume.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { GrovePayloadPlume } from "src/libraries/GrovePayloadPlume.sol";

contract GrovePlume_20250918 is GrovePayloadPlume {

    address internal constant FAKE_ADDRESS_PLACEHOLDER    = 0x00000000000000000000000000000000DeaDBeef;
    address internal constant PLUME_CENTRIFUGE_ACRDX_VAULT = 0x0000000000000000000000000000000000000000; // TODO: Add actual address

    uint256 internal constant PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                   // TODO: Add actual value
    uint256 internal constant PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 100_000_000e6 / uint256(1 days); // TODO: Add actual value

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID = 1;

    function execute() external {
        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _initializeLiquidityLayer();

        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _onboardCentrifugeAcrdxCrosschainTransfer();
    }

    function _initializeLiquidityLayer() internal {
        // Define Plume relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Plume.ALM_RELAYER;

        ForeignControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new ForeignControllerInit.CentrifugeRecipient[](1);
        centrifugeRecipients[0] = ForeignControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            recipient               : bytes32(uint256(uint160(Ethereum.ALM_PROXY)))
        });

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : Plume.ALM_PROXY,
                controller : Plume.ALM_CONTROLLER,
                rateLimits : Plume.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Plume.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin      : Plume.GROVE_EXECUTOR,
                psm        : FAKE_ADDRESS_PLACEHOLDER,
                cctp       : FAKE_ADDRESS_PLACEHOLDER,
                usdc       : FAKE_ADDRESS_PLACEHOLDER
            }),
            new ForeignControllerInit.MintRecipient[](0),
            new ForeignControllerInit.LayerZeroRecipient[](0),
            centrifugeRecipients
        );
    }

    function _onboardCentrifugeAcrdxCrosschainTransfer() internal {
        _setCentrifugeCrosschainTransferRateLimit(
            PLUME_CENTRIFUGE_ACRDX_VAULT,
            ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }
}
