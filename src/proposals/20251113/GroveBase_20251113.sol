// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { LZForwarder }   from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadBase } from "src/libraries/payloads/GrovePayloadBase.sol";

/**
 * @title  November 13, 2025 Grove Base Proposal
 * @author Grove Labs
 */
contract GroveBase_20251113 is GrovePayloadBase {

    function execute() external {
        // // TODO: Item title
        //   Forum : TODO: Forum link
        _initializeLiquidityLayer();

        // TODO: Item title
        //   Forum : TODO: Forum link
        _onboardMorphoVault(); // TODO: Rename to more precisely describe the onboarding

        // TODO: Item title
        //   Forum : TODO: Forum link
        _onboardCurvePool(); // TODO: Rename to more precisely describe the onboarding
    }

    function _initializeLiquidityLayer() internal {
        // Define Base relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Base.ALM_RELAYER;


        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](1);
        mintRecipients[0] = ForeignControllerInit.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.LayerZeroRecipient[] memory layerZeroRecipients = new ForeignControllerInit.LayerZeroRecipient[](1);
        layerZeroRecipients[0] = ForeignControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_ETHEREUM,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new ForeignControllerInit.CentrifugeRecipient[](1);
        centrifugeRecipients[0] = ForeignControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : Base.ALM_PROXY,
                controller : Base.ALM_CONTROLLER,
                rateLimits : Base.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Base.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin      : Base.GROVE_EXECUTOR,
                cctp       : Base.CCTP_TOKEN_MESSENGER,
                psm        : Base.PSM3,
                usdc       : Base.USDC
            }),
            mintRecipients,
            layerZeroRecipients,
            centrifugeRecipients
        );
    }

    function _onboardMorphoVault() internal {
        // TODO: Implement
    }

    function _onboardCurvePool() internal {
        // TODO: Implement
    }

}
