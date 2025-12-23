// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";
import { LZForwarder }     from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/MainnetControllerInit.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  January 15, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260115 is GrovePayloadEthereum {

    address internal constant NEW_CONTROLLER    = 0x0000000000000000000000000000000000000000; // TODO: Replace with actual new mainnet controller address
    address internal constant SECONDARY_RELAYER = 0x0000000000000000000000000000000000000000; // TODO: Replace with actual secondary relayer address

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {

        // TODO Item title
        //   Forum : TODO forum link
        // _upgradeController(); // TODO Uncomment when the controller upgrade is properly implemented

        // TODO Item title
        //   Forum : TODO forum link
        _onboardCctpTransfersToBase();

        // TODO Item title
        //   Forum : TODO forum link
        _offboardAgoraAusd();
    }

    function _upgradeController() internal {
        address[] memory relayers = new address[](2);
        relayers[0] = Ethereum.ALM_RELAYER;
        relayers[1] = SECONDARY_RELAYER;

        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](3);
        mintRecipients[0] = MainnetControllerInit.MintRecipient({
            domain        : CCTPv2Forwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Avalanche.ALM_PROXY)
        });
        mintRecipients[1] = MainnetControllerInit.MintRecipient({
            domain        : CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY)
        });
        mintRecipients[2] = MainnetControllerInit.MintRecipient({
            domain        : CCTPv2Forwarder.DOMAIN_ID_CIRCLE_PLUME,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Plume.ALM_PROXY)
        });

        MainnetControllerInit.LayerZeroRecipient[] memory layerZeroRecipients = new MainnetControllerInit.LayerZeroRecipient[](3);
        layerZeroRecipients[0] = MainnetControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_AVALANCHE,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Avalanche.ALM_PROXY)
        });
        layerZeroRecipients[1] = MainnetControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_BASE,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Base.ALM_PROXY)
        });
        layerZeroRecipients[2] = MainnetControllerInit.LayerZeroRecipient({
            destinationEndpointId : 30318, // Plume endpoint ID
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Plume.ALM_PROXY)
        });

        MainnetControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new MainnetControllerInit.CentrifugeRecipient[](3);
        centrifugeRecipients[0] = MainnetControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Avalanche.ALM_PROXY)
        });
        centrifugeRecipients[1] = MainnetControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : GroveLiquidityLayerHelpers.BASE_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Base.ALM_PROXY)
        });
        centrifugeRecipients[2] = MainnetControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY)
        });

        MainnetControllerInit.upgradeController(
            ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : NEW_CONTROLLER, // TODO Make sure to use the post-audit version
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            MainnetControllerInit.ConfigAddressParams({
                freezer       : Ethereum.ALM_FREEZER,
                relayers      : relayers,
                oldController : Ethereum.ALM_CONTROLLER
            }),
            MainnetControllerInit.CheckAddressParams({
                admin      : Ethereum.GROVE_PROXY,
                proxy      : Ethereum.ALM_PROXY,
                rateLimits : Ethereum.ALM_RATE_LIMITS,
                vault      : Ethereum.ALLOCATOR_VAULT,
                psm        : Ethereum.PSM,
                daiUsds    : Ethereum.DAI_USDS,
                cctp       : Ethereum.CCTP_TOKEN_MESSENGER // TODO: Replace with CCTP_TOKEN_MESSENGER_V2
            }),
            mintRecipients,
            layerZeroRecipients,
            centrifugeRecipients
        );
    }

    function _onboardCctpTransfersToBase() internal {
        // General key rate limit for all CCTP transfers was set in the GroveEthereum_20250807 proposal

        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(domainKey, CCTP_RATE_LIMIT_MAX, CCTP_RATE_LIMIT_SLOPE);
    }

    function _offboardAgoraAusd() internal {
        // TODO Implement or remove this item if not needed
    }

}
