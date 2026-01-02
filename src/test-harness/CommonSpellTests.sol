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

import { GroveLiquidityLayerContext, CommonTestBase } from "./CommonTestBase.sol";

abstract contract CommonSpellTests is CommonTestBase {

    struct BridgeTypesToTest {
        bool cctp;
        bool centrifuge;
        bool layerZero;
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    uint256 public constant AVERAGE_EXECUTION_COST_TARGET = 15_000_000;
    uint256 public constant MAX_EXECUTION_COST            = 30_000_000;

    /**********************************************************************************************/
    /*** Tests                                                                                  ***/
    /**********************************************************************************************/

    function test_ETHEREUM_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Ethereum());
    }

    function test_ETHEREUM_ExecutionCost() public {
        uint256 startGas = gasleft();
        executeAllPayloadsAndBridges();
        uint256 endGas = gasleft();
        uint256 totalGas = startGas - endGas;

        // Warn if deploy exceeds block target size
        if (totalGas > AVERAGE_EXECUTION_COST_TARGET) {
            emit log("Warn: deploy gas exceeds average block target");
            emit log_named_uint("    deploy gas", totalGas);
            emit log_named_uint("  block target", AVERAGE_EXECUTION_COST_TARGET);
        }

        // Fail if deploy is too expensive
        assertLe(totalGas, MAX_EXECUTION_COST, "TestError/spell-deploy-cost-too-high");
    }

    function test_ETHEREUM_ForeignRecipientsSet() public {
        _testForeignDomainsRecipientsSetting();
    }

    function test_AVALANCHE_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Avalanche());
    }

    function test_AVALANCHE_ForeignRecipientsSet() public {
        _testMainnetDomainRecipientsSetting(
            ChainIdUtils.Avalanche(),
            BridgeTypesToTest({
                cctp       : true,
                centrifuge : false, // Centrifuge crosschain transfers are not onboarded on Avalanche yet
                layerZero  : false  // LayerZero  crosschain transfers are not onboarded on Avalanche yet
            })
        );
    }

    function test_BASE_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Base());
    }

    function test_BASE_ForeignRecipientsSet() public {
        _testMainnetDomainRecipientsSetting(
            ChainIdUtils.Base(),
            BridgeTypesToTest({
                cctp       : true,
                centrifuge : true,
                layerZero  : true
            })
        );
    }

    function test_PLUME_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Plume());
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

    function _assertPayloadBytecodeMatches(ChainId chainId) private onChain(chainId) {
        address actualPayload = chainData[chainId].payload;
        vm.skip(actualPayload == address(0));
        require(_isContract(actualPayload), "PAYLOAD IS NOT A CONTRACT");
        address expectedPayload = deployPayload(chainId);

        uint256 expectedBytecodeSize = expectedPayload.code.length;
        uint256 actualBytecodeSize   = actualPayload.code.length;

        uint256 metadataLength = _getBytecodeMetadataLength(expectedPayload);
        assertTrue(metadataLength <= expectedBytecodeSize);
        expectedBytecodeSize -= metadataLength;

        metadataLength = _getBytecodeMetadataLength(actualPayload);
        assertTrue(metadataLength <= actualBytecodeSize);
        actualBytecodeSize -= metadataLength;

        assertEq(actualBytecodeSize, expectedBytecodeSize);

        uint256 size = actualBytecodeSize;
        uint256 expectedHash;
        uint256 actualHash;

        assembly {
            let ptr := mload(0x40)

            extcodecopy(expectedPayload, ptr, 0, size)
            expectedHash := keccak256(ptr, size)

            extcodecopy(actualPayload, ptr, 0, size)
            actualHash := keccak256(ptr, size)
        }

        assertEq(actualHash, expectedHash);
    }

    function _getBytecodeMetadataLength(address a) internal view returns (uint256 length) {
        // The Solidity compiler encodes the metadata length in the last two bytes of the contract bytecode.
        assembly {
            let ptr  := mload(0x40)
            let size := extcodesize(a)
            if iszero(lt(size, 2)) {
                extcodecopy(a, ptr, sub(size, 2), 2)
                length := mload(ptr)
                length := shr(240, length)
                length := add(length, 2)  // The two bytes used to specify the length are not counted in the length
            }
            // Return zero if the bytecode is shorter than two bytes.
        }
    }

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
            "CommonTest/Avalanche/incorrect-cctp-recipient"
        );

        // Centrifuge
        assertEq(
            controller.centrifugeRecipients(GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID),
            CastingHelpers.addressToCentrifugeRecipient(Avalanche.ALM_PROXY),
            "CommonTest/Avalanche/incorrect-centrifuge-recipient"
        );

        // LayerZero
        assertEq(
            controller.layerZeroRecipients(LZForwarder.ENDPOINT_ID_AVALANCHE),
            CastingHelpers.addressToLayerZeroRecipient(Avalanche.ALM_PROXY),
            "CommonTest/Avalanche/incorrect-layerzero-recipient"
        );

        /**********************************************************************************************/
        /*** Base                                                                                  ***/
        /**********************************************************************************************/

        // CCTP
        assertEq(
            controller.mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE),
            CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY),
            "CommonTest/Base/incorrect-cctp-recipient"
        );

        // Centrifuge
        assertEq(
            controller.centrifugeRecipients(GroveLiquidityLayerHelpers.BASE_DESTINATION_CENTRIFUGE_ID),
            CastingHelpers.addressToCentrifugeRecipient(Base.ALM_PROXY),
            "CommonTest/Base/incorrect-centrifuge-recipient"
        );

        // LayerZero
        assertEq(
            controller.layerZeroRecipients(LZForwarder.ENDPOINT_ID_BASE),
            CastingHelpers.addressToLayerZeroRecipient(Base.ALM_PROXY),
            "CommonTest/Base/incorrect-layerzero-recipient"
        );

        /**********************************************************************************************/
        /*** Plume                                                                                  ***/
        /**********************************************************************************************/

        // CCTP
        assertEq(
            controller.mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_PLUME),
            CastingHelpers.addressToCctpRecipient(Plume.ALM_PROXY),
            "CommonTest/Plume/incorrect-cctp-recipient"
        );

        // Centrifuge
        assertEq(
            controller.centrifugeRecipients(GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID),
            CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY),
            "CommonTest/Plume/incorrect-centrifuge-recipient"
        );

        // LayerZero
        assertEq(
            controller.layerZeroRecipients(30318), // Plume endpoint ID
            CastingHelpers.addressToLayerZeroRecipient(Plume.ALM_PROXY),
            "CommonTest/Plume/incorrect-layerzero-recipient"
        );
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
                "CommonTest/Mainnet/incorrect-cctp-recipient"
            );
        }

        // Centrifuge
        if (bridgeTypesToTest.centrifuge) {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY),
                "CommonTest/Mainnet/incorrect-centrifuge-recipient"
            );
        }

        // LayerZero
        if (bridgeTypesToTest.layerZero) {
            assertEq(
                controller.layerZeroRecipients(LZForwarder.ENDPOINT_ID_ETHEREUM),
                CastingHelpers.addressToLayerZeroRecipient(Ethereum.ALM_PROXY),
                "CommonTest/Mainnet/incorrect-layerzero-recipient"
            );
        }
    }

}
