// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ChainIdUtils, ChainId } from "src/libraries/helpers/ChainId.sol";

import { CommonTestBase } from "./CommonTestBase.sol";

abstract contract CommonSpellTests is CommonTestBase {

    uint256 public constant AVERAGE_EXECUTION_COST_TARGET = 15_000_000;
    uint256 public constant MAX_EXECUTION_COST            = 30_000_000;

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

    function test_AVALANCHE_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Avalanche());
    }

    function test_PLUME_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Plume());
    }

    function test_BASE_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Base());
    }

    function test_PLASMA_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Plasma());
    }

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

}
