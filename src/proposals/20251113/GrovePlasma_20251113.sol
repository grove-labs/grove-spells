// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { LZForwarder } from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plasma }   from "lib/grove-address-registry/src/Plasma.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadPlasma } from "src/libraries/payloads/GrovePayloadPlasma.sol";

/**
 * @title  November 13, 2025 Grove Plasma Proposal
 * @author Grove Labs
 */
contract GrovePlasma_20251113 is GrovePayloadPlasma {

    function execute() external {
        // // TODO: Item title
        //   Forum : TODO: Forum link
        _initializeLiquidityLayer();

        // TODO: Item title
        //   Forum : TODO: Forum link
        _onboardAave(); // TODO: Rename to more precisely describe the onboarding
    }

    function _initializeLiquidityLayer() internal {
        // Define Plasma relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Plasma.ALM_RELAYER;

        // Empty CCTPv1 mint recipients - CCTPv1 not deployed on Plasma
        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](0);

        // Empty Centrifuge recipients - Centrifuge not deployed on Plasma
        ForeignControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new ForeignControllerInit.CentrifugeRecipient[](0);

        ForeignControllerInit.LayerZeroRecipient[] memory layerZeroRecipients = new ForeignControllerInit.LayerZeroRecipient[](1);
        layerZeroRecipients[0] = ForeignControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_ETHEREUM,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : Plasma.ALM_PROXY,
                controller : Plasma.ALM_CONTROLLER,
                rateLimits : Plasma.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Plasma.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin      : Plasma.GROVE_EXECUTOR,
                psm        : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                cctp       : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                usdc       : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER
            }),
            mintRecipients,
            layerZeroRecipients,
            centrifugeRecipients
        );
    }

    function _onboardAave() internal {
        // TODO: Implement
    }

}
