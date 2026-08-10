// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils, ChainId } from "src/libraries/helpers/ChainId.sol";

import { CommonTestBase } from "./CommonTestBase.sol";

interface IPsmFeesLike {
    function tin() external view returns (uint256);
    function tout() external view returns (uint256);
}

interface IGroveProxyLike {
    function wards(address usr) external view returns (uint256);
}

/// @dev System-agnostic spell tests that apply to every spell regardless of
/// which ALM system (legacy ALM controller or PAU controller) it touches:
/// payload bytecode verification and execution cost.
/// Controller-system-specific tests live in CommonALMSpellTests and
/// CommonPauSpellTests.
abstract contract CommonSpellTests is CommonTestBase {

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

    function test_ETHEREUM_PayloadsConfigured() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(chainData[ChainIdUtils.Ethereum()].payload == address(0));

        for (uint256 i = 0; i < allChains.length; ++i) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            if (chainId == ChainIdUtils.Ethereum()) continue;

            address deployedPayload = chainData[chainId].payload;
            if (deployedPayload == address(0)) continue;

            address mainnetSpellPayload = _getForeignPayloadFromMainnetSpell(chainId);
            // address(0) means the mainnet spell does not wire this chain yet; foreign
            // execution is then simulated locally, so there is nothing to cross-check
            if (mainnetSpellPayload == address(0)) continue;

            assertEq(
                mainnetSpellPayload,
                deployedPayload,
                "CommonTest/mainnet-payload-not-matching-deployed"
            );
        }
    }

    function test_ETHEREUM_ExecutionCost() public {
        vm.skip(chainData[ChainIdUtils.Ethereum()].payload == address(0));

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
        assertLe(totalGas, MAX_EXECUTION_COST, "CommonTest/spell-deploy-cost-too-high");
    }

    function test_ETHEREUM_PsmFeesAreZero() public onChain(ChainIdUtils.Ethereum()) {
        IPsmFeesLike psm = IPsmFeesLike(Ethereum.PSM);

        assertEq(psm.tin(),  0, "CommonTest/psm-tin-not-zero");
        assertEq(psm.tout(), 0, "CommonTest/psm-tout-not-zero");

        executeAllPayloadsAndBridges();

        assertEq(psm.tin(),  0, "CommonTest/psm-tin-not-zero-after-spell");
        assertEq(psm.tout(), 0, "CommonTest/psm-tout-not-zero-after-spell");
    }

    function test_ETHEREUM_GroveProxyStorage() public onChain(ChainIdUtils.Ethereum()) {
        _assertGroveProxyStorage();

        executeAllPayloadsAndBridges();

        _assertGroveProxyStorage();
    }

    function test_AVALANCHE_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Avalanche());
    }

    function test_BASE_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Base());
    }

    function test_PLUME_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Plume());
    }

    function test_ROBINHOOD_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Robinhood());
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                      ***/
    /**********************************************************************************************/

    // Mainnet payloads run via delegatecall from GROVE_PROXY, so a payload writing to
    // storage would corrupt the proxy. Its wards live in a mapping (keccak-derived slots),
    // so every direct slot is expected to stay zero.
    function _assertGroveProxyStorage() private view {
        assertEq(IGroveProxyLike(Ethereum.GROVE_PROXY).wards(Ethereum.PAUSE_PROXY),      1, "CommonTest/grove-proxy-pause-proxy-not-ward");
        assertEq(IGroveProxyLike(Ethereum.GROVE_PROXY).wards(Ethereum.GROVE_STAR_GUARD), 1, "CommonTest/grove-proxy-star-guard-not-ward");

        for (uint256 slot; slot <= 100; ++slot) {
            assertEq(vm.load(Ethereum.GROVE_PROXY, bytes32(slot)), bytes32(0), "CommonTest/grove-proxy-slot-not-zero");
        }
    }

    function _assertPayloadBytecodeMatches(ChainId chainId) private onChain(chainId) {
        address actualPayload = chainData[chainId].payload;
        vm.skip(actualPayload == address(0));
        require(_isContract(actualPayload), "PAYLOAD IS NOT A CONTRACT");
        address expectedPayload = deployPayload(chainId);

        uint256 expectedBytecodeSize = expectedPayload.code.length;
        uint256 actualBytecodeSize   = actualPayload.code.length;

        uint256 metadataLength = _getBytecodeMetadataLength(expectedPayload);
        assertTrue(metadataLength <= expectedBytecodeSize, "CommonTest/metadata-length-not-correct");
        expectedBytecodeSize -= metadataLength;

        metadataLength = _getBytecodeMetadataLength(actualPayload);
        assertTrue(metadataLength <= actualBytecodeSize, "CommonTest/metadata-length-not-correct");
        actualBytecodeSize -= metadataLength;

        assertEq(actualBytecodeSize, expectedBytecodeSize, "CommonTest/bytecode-size-not-correct");

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

        assertEq(actualHash, expectedHash, "CommonTest/bytecode-hash-not-correct");
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
