// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";
import { LZForwarder }     from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { ChainIdUtils, ChainId }      from "src/libraries/helpers/ChainId.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveLiquidityLayerContext } from "./CommonTestBase.sol";

import { CommonSpellTests } from "./CommonSpellTests.sol";

/// @dev Spell tests specific to the legacy ALM controller system
/// (grove-alm-controller MainnetController/ForeignController + ALM_PROXY).
abstract contract CommonALMSpellTests is CommonSpellTests {

    bytes32 internal constant GROVE_ALM_ALLOCATOR_ILK = "ALLOCATOR-BLOOM-A";

    struct BridgeTypesToTest {
        bool cctp;
        bool centrifuge;
        bool layerZero;
    }

    /**********************************************************************************************/
    /*** Tests                                                                                  ***/
    /**********************************************************************************************/

    function test_ETHEREUM_ForeignRecipientsSet() public {
        _testForeignDomainsRecipientsSetting();
    }

    function test_AVALANCHE_ForeignRecipientsSet() public {
        _testMainnetDomainRecipientsSetting(
            ChainIdUtils.Avalanche(),
            BridgeTypesToTest({
                cctp       : true,
                centrifuge : true,
                layerZero  : true
            })
        );
    }

    function test_BASE_ForeignRecipientsSet() public {
        _testMainnetDomainRecipientsSetting(
            ChainIdUtils.Base(),
            BridgeTypesToTest({
                cctp       : true,
                centrifuge : false, // Centrifuge crosschain transfers are not onboarded on Base yet
                layerZero  : false  // LayerZero  crosschain transfers are not onboarded on Base yet
            })
        );
    }

    function test_PLUME_ForeignRecipientsSet() public {
        _testMainnetDomainRecipientsSetting(
            ChainIdUtils.Plume(),
            BridgeTypesToTest({
                cctp       : false, // CCTPv2 crosschain transfers are not onboarded on Plume yet
                centrifuge : true,
                layerZero  : false  // LayerZero crosschain transfers are not onboarded on Plume yet
            })
        );
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                      ***/
    /**********************************************************************************************/

    function _testForeignDomainsRecipientsSetting() private {
        executeAllPayloadsAndBridges();

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        MainnetController controller = MainnetController(ctx.controller);

        /**********************************************************************************************/
        /*** Avalanche                                                                              ***/
        /**********************************************************************************************/

        // CCTP
        assertEq(
            controller.mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_AVALANCHE),
            CastingHelpers.addressToCctpRecipient(Avalanche.ALM_PROXY),
            "CommonTest/avalanche/incorrect-cctp-recipient"
        );

        // Centrifuge
        assertEq(
            controller.centrifugeRecipients(GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID),
            CastingHelpers.addressToCentrifugeRecipient(Avalanche.ALM_PROXY),
            "CommonTest/avalanche/incorrect-centrifuge-recipient"
        );

        // LayerZero
        assertEq(
            controller.layerZeroRecipients(LZForwarder.ENDPOINT_ID_AVALANCHE),
            CastingHelpers.addressToLayerZeroRecipient(Avalanche.ALM_PROXY),
            "CommonTest/avalanche/incorrect-layerzero-recipient"
        );

        /**********************************************************************************************/
        /*** Base                                                                                  ***/
        /**********************************************************************************************/

        // CCTP
        assertEq(
            controller.mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE),
            CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY),
            "CommonTest/base/incorrect-cctp-recipient"
        );

        // Centrifuge
        // NOTE Centrifuge crosschain transfers to Base are not onboarded yet

        // LayerZero
        // NOTE LayerZero crosschain transfers to Base are not onboarded yet

        /**********************************************************************************************/
        /*** Plume                                                                                  ***/
        /**********************************************************************************************/

        // CCTP
        // NOTE CCTPv2 crosschain transfers to Plume are not onboarded yet

        // Centrifuge
        assertEq(
            controller.centrifugeRecipients(GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID),
            CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY),
            "CommonTest/plume/incorrect-centrifuge-recipient"
        );

        // LayerZero
        // NOTE LayerZero crosschain transfers to Plume are not onboarded yet
    }

    function _testMainnetDomainRecipientsSetting(ChainId chainId, BridgeTypesToTest memory bridgeTypesToTest) private onChain(chainId) {
        executeAllPayloadsAndBridges();

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        ForeignController controller = ForeignController(ctx.controller);

        // CCTP
        if (bridgeTypesToTest.cctp) {
            assertEq(
                controller.mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
                CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY),
                "CommonTest/mainnet/incorrect-cctp-recipient"
            );
        }

        // Centrifuge
        if (bridgeTypesToTest.centrifuge) {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY),
                "CommonTest/mainnet/incorrect-centrifuge-recipient"
            );
        }

        // LayerZero
        if (bridgeTypesToTest.layerZero) {
            assertEq(
                controller.layerZeroRecipients(LZForwarder.ENDPOINT_ID_ETHEREUM),
                CastingHelpers.addressToLayerZeroRecipient(Ethereum.ALM_PROXY),
                "CommonTest/mainnet/incorrect-layerzero-recipient"
            );
        }
    }

}
