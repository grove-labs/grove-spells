// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test }      from "forge-std/Test.sol";
import { StdChains } from "forge-std/StdChains.sol";
import { console }   from "forge-std/console.sol";

import { Ethereum }  from 'grove-address-registry/Ethereum.sol';
import { Avalanche } from 'grove-address-registry/Avalanche.sol';
import { Base }      from 'grove-address-registry/Base.sol';
import { Plume }     from 'grove-address-registry/Plume.sol';

import { IExecutor } from 'lib/grove-gov-relay/src/interfaces/IExecutor.sol';

import { Bridge, BridgeType }    from "xchain-helpers/testing/Bridge.sol";
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { RecordedLogs }          from "xchain-helpers/testing/utils/RecordedLogs.sol";

import { OptimismBridgeTesting } from "xchain-helpers/testing/bridges/OptimismBridgeTesting.sol";
import { AMBBridgeTesting }      from "xchain-helpers/testing/bridges/AMBBridgeTesting.sol";
import { ArbitrumBridgeTesting } from "xchain-helpers/testing/bridges/ArbitrumBridgeTesting.sol";
import { CCTPBridgeTesting }     from "xchain-helpers/testing/bridges/CCTPBridgeTesting.sol";
import { LZBridgeTesting }       from "xchain-helpers/testing/bridges/LZBridgeTesting.sol";

import { ChainIdUtils, ChainId } from "../libraries/helpers/ChainId.sol";

import { GrovePayloadEthereum } from "../libraries/payloads/GrovePayloadEthereum.sol";

interface IStarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
    function exec() external returns (address);
}

abstract contract SpellRunner is Test {
    using DomainHelpers for Domain;
    using DomainHelpers for StdChains.Chain;

    // ChainData is already taken in StdChains
    struct DomainData {
        address   payload;
        IExecutor executor;
        Domain    domain;
        /// @notice on mainnet: empty
        /// on L2s: bridges that'll include txs in the L2. there can be multiple
        /// bridges for a given chain, such as canonical OP bridge and CCTP
        /// USDC-specific bridge
        Bridge[]  bridges;
        address   prevController;
        address   newController;
        bool      spellExecuted;
    }

    mapping(ChainId => DomainData) internal chainData;

    ChainId[] internal allChains;
    string internal    id;

    modifier onChain(ChainId chainId) {
        uint256 currentFork = vm.activeFork();
        selectChain(chainId);
        _;
        if (vm.activeFork() != currentFork) vm.selectFork(currentFork);
    }

    function selectChain(ChainId chainId) internal {
        if (chainData[chainId].domain.forkId != vm.activeFork()) chainData[chainId].domain.selectFork();
    }

    /// @dev Query Etherscan "get block number by timestamp" endpoint for multiple chains.
    /// The 'chainIds' array should have the chain IDs [1, 43114, 8453, ...]
    /// and the function expects environment variables: ETHERSCAN_API_KEY
    function getBlocksFromDateByChainIds(string memory date, ChainId[] memory chainIds) internal returns (uint256[] memory blocks) {
        require(chainIds.length > 0, "No chains provided");
        blocks = new uint256[](chainIds.length);

        string memory timestampString = isoToUnix(date);

        for (uint256 i = 0; i < chainIds.length; ++i) {
            string memory urlBase   = "https://api.etherscan.io/v2/api?";
            string memory apiKeyEnv = "ETHERSCAN_API_KEY";
            string memory apiKey    = vm.envString(apiKeyEnv);
            string memory chainId   = vm.toString(ChainId.unwrap(chainIds[i]));

            string memory url = string(
                abi.encodePacked(
                    urlBase,
                    "chainId=", chainId,
                    "&module=block",
                    "&action=getblocknobytime",
                    "&timestamp=", timestampString,
                    "&closest=after",
                    "&apikey=", apiKey
                )
            );

            string[] memory curlCmd = new string[](8);
            curlCmd[0] = "curl";
            curlCmd[1] = "-s";
            curlCmd[2] = "--request";
            curlCmd[3] = "GET";
            curlCmd[4] = "--url";
            curlCmd[5] = url;
            curlCmd[6] = "--header";
            curlCmd[7] = "accept: application/json";

            string memory response = string(vm.ffi(curlCmd));
            // Result: {"status":"1","message":"OK","result":"18518418"}
            blocks[i] = vm.parseJsonUint(response, ".result");
        }
    }

    function isoToUnix(string memory iso) internal returns (string memory) {
        // Build a bash script that works on both GNU date (Linux) and BSD date (macOS)
        string memory sh = string.concat(
            "ISO='", iso, "'; ",
            "if date --version >/dev/null 2>&1; then ",
                "date -d \"$ISO\" +%s; ",
            "else ",
                "date -j -f '%Y-%m-%dT%H:%M:%SZ' \"$ISO\" +%s; ",
            "fi"
        );

        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-lc";
        cmd[2] = sh;

        bytes memory out = vm.ffi(cmd);
        return strip0x(vm.toString(out));
    }

    function strip0x(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length >= 2 && b[0] == "0" && (b[1] == "x" || b[1] == "X")) {
            bytes memory out = new bytes(b.length - 2);
            for (uint256 i = 2; i < b.length; i++) {
                out[i - 2] = b[i];
            }
            return string(out);
        }
        return s;
    }

    function bytesToUint(bytes memory b) internal override pure returns (uint256 x) {
        require(b.length <= 32, "too long");
        assembly {
            x := mload(add(b, 32))
        }
    }

    function setupBlocksFromDate(string memory date) internal {
        setChain("plume", ChainData({
            name    : "Plume",
            rpcUrl  : vm.envString("PLUME_RPC_URL"),
            chainId : 98866
        }));

        ChainId[] memory chainIds = new ChainId[](3);
        chainIds[0] = ChainIdUtils.Ethereum();
        chainIds[1] = ChainIdUtils.Avalanche();
        chainIds[2] = ChainIdUtils.Base();

        uint256[] memory blocks = getBlocksFromDateByChainIds(date, chainIds);

        chainData[ChainIdUtils.Ethereum()].domain  = getChain("mainnet").createFork(blocks[0]);
        chainData[ChainIdUtils.Avalanche()].domain = getChain("avalanche").createFork(blocks[1]);
        chainData[ChainIdUtils.Base()].domain      = getChain("base").createFork(blocks[2]);

        uint256[] memory hardcodedBlocks = new uint256[](1);
        hardcodedBlocks[0] = 30242550; // Plume

        chainData[ChainIdUtils.Plume()].domain = getChain("plume").createFork(hardcodedBlocks[0]);

        console.log("   Mainnet block:", blocks[0]);
        console.log(" Avalanche block:", blocks[1]);
        console.log("      Base block:", blocks[2]);
        console.log("     Plume block:", hardcodedBlocks[0]);
    }

    /// @dev to be called in setUp
    function setupDomains(string memory date) internal {
        setupBlocksFromDate(date);

        // We default to Ethereum domain
        chainData[ChainIdUtils.Ethereum()].domain.selectFork();

        chainData[ChainIdUtils.Ethereum()].executor       = IExecutor(Ethereum.GROVE_PROXY);
        chainData[ChainIdUtils.Ethereum()].prevController = Ethereum.ALM_CONTROLLER;
        chainData[ChainIdUtils.Ethereum()].newController  = Ethereum.ALM_CONTROLLER;

        chainData[ChainIdUtils.Avalanche()].executor       = IExecutor(Avalanche.GROVE_EXECUTOR);
        chainData[ChainIdUtils.Avalanche()].prevController = Avalanche.ALM_CONTROLLER;
        chainData[ChainIdUtils.Avalanche()].newController  = Avalanche.ALM_CONTROLLER;

        chainData[ChainIdUtils.Base()].executor       = IExecutor(Base.GROVE_EXECUTOR);
        chainData[ChainIdUtils.Base()].prevController = Base.ALM_CONTROLLER;
        chainData[ChainIdUtils.Base()].newController  = Base.ALM_CONTROLLER;

        chainData[ChainIdUtils.Plume()].executor       = IExecutor(Plume.GROVE_EXECUTOR);
        chainData[ChainIdUtils.Plume()].prevController = Plume.ALM_CONTROLLER;
        chainData[ChainIdUtils.Plume()].newController  = Plume.ALM_CONTROLLER;

        // Avalanche
        chainData[ChainIdUtils.Avalanche()].bridges.push(
            CCTPBridgeTesting.createCircleBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Avalanche()].domain
            )
        );

        // Base
        chainData[ChainIdUtils.Base()].bridges.push(
            OptimismBridgeTesting.createNativeBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Base()].domain
            )
        );
        chainData[ChainIdUtils.Base()].bridges.push(
            CCTPBridgeTesting.createCircleBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Base()].domain
            )
        );

        // Plume
        chainData[ChainIdUtils.Plume()].bridges.push(
            ArbitrumBridgeTesting.createNativeBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Plume()].domain
            )
        );

        allChains.push(ChainIdUtils.Ethereum());
        allChains.push(ChainIdUtils.Avalanche());
        allChains.push(ChainIdUtils.Base());
        allChains.push(ChainIdUtils.Plume());
    }

    function spellIdentifier(ChainId chainId) private view returns(string memory) {
        string memory slug       = string(abi.encodePacked("Grove", chainId.toDomainString(), "_", id));
        string memory identifier = string(abi.encodePacked(slug, ".sol:", slug));
        return identifier;
    }

    function deployPayload(ChainId chainId) internal onChain(chainId) returns(address) {
        return deployCode(spellIdentifier(chainId));
    }

    function deployPayloads() internal {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            string memory identifier = spellIdentifier(chainId);
            try vm.getCode(identifier) {
                chainData[chainId].payload = deployPayload(chainId);
                chainData[chainId].spellExecuted = false;
                console.log("deployed payload for network: ", chainId.toDomainString());
                console.log("             payload address: ", chainData[chainId].payload);
            } catch {
                console.log("skipping spell deployment for network: ", chainId.toDomainString());
            }
        }
    }

    /// @dev takes care to revert the selected fork to what was chosen before
    function executeAllPayloadsAndBridges() internal {
        // only execute mainnet payload
        executeMainnetPayload();
        // then use bridges to execute other chains' payloads
        _relayMessageOverBridges(allChains);
        // execute the foreign payloads (either by simulation or real execute)
        _executeForeignPayloads();
    }

    /// @dev bridge contracts themselves are stored on mainnet
    function _relayMessageOverBridges(ChainId[] memory chains) internal onChain(ChainIdUtils.Ethereum()) {
        for (uint256 i = 0; i < chains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[chains[i]].domain);
            for (uint256 j = 0; j < chainData[chainId].bridges.length ; j++){
                _executeBridge(chainData[chainId].bridges[j]);
            }
        }
    }

    /// @dev this does not relay messages from L2s to mainnet except in the case of USDC
    function _executeBridge(Bridge storage bridge) private {
        if (bridge.bridgeType == BridgeType.OPTIMISM) {
            OptimismBridgeTesting.relayMessagesToDestination(bridge, false);
        } else if (bridge.bridgeType == BridgeType.CCTP) {
            CCTPBridgeTesting.relayMessagesToDestination(bridge, false);
            CCTPBridgeTesting.relayMessagesToSource(bridge, false);
        } else if (bridge.bridgeType == BridgeType.AMB) {
            AMBBridgeTesting.relayMessagesToDestination(bridge, false);
        } else if (bridge.bridgeType == BridgeType.ARBITRUM) {
            ArbitrumBridgeTesting.relayMessagesToDestination(bridge, false);
        }
    }

    function _executeForeignPayloads() private onChain(ChainIdUtils.Ethereum()) {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            if (chainId == ChainIdUtils.Ethereum()) continue;  // Don't execute mainnet

            address mainnetSpellPayload = _getForeignPayloadFromMainnetSpell(chainId);
            IExecutor executor = chainData[chainId].executor;
            if (mainnetSpellPayload != address(0)) {
                // We assume the payload has been queued in the executor (will revert otherwise)
                chainData[chainId].domain.selectFork();
                uint256 actionsSetId = executor.actionsSetCount() - 1;
                uint256 prevTimestamp = block.timestamp;
                vm.warp(executor.getActionsSetById(actionsSetId).executionTime);
                executor.execute(actionsSetId);
                chainData[chainId].spellExecuted = true;
                vm.warp(prevTimestamp);
            } else {
                // We will simulate execution until the real spell is deployed in the mainnet spell
                address payload = chainData[chainId].payload;
                if (payload != address(0)) {
                    chainData[chainId].domain.selectFork();
                    vm.prank(address(executor));
                    executor.executeDelegateCall(
                        payload,
                        abi.encodeWithSignature('execute()')
                    );
                    chainData[chainId].spellExecuted = true;
                    console.log("simulating execution payload for network: ", chainId.toDomainString());
                }
            }

        }
    }

    function _getForeignPayloadFromMainnetSpell(ChainId chainId) internal onChain(ChainIdUtils.Ethereum()) returns (address) {
        GrovePayloadEthereum spell = GrovePayloadEthereum(chainData[ChainIdUtils.Ethereum()].payload);

        if (chainId == ChainIdUtils.Avalanche()) return spell.PAYLOAD_AVALANCHE();
        if (chainId == ChainIdUtils.Base())      return spell.PAYLOAD_BASE();
        if (chainId == ChainIdUtils.Plume())     return spell.PAYLOAD_PLUME();

        revert("Unsupported chainId");
    }

    function executeMainnetPayload() internal onChain(ChainIdUtils.Ethereum()) {
        address payloadAddress = chainData[ChainIdUtils.Ethereum()].payload;

        require(_isContract(payloadAddress),                         "PAYLOAD IS NOT A CONTRACT");
        require(GrovePayloadEthereum(payloadAddress).isExecutable(), "MAINNET PAYLOAD IS NOT EXECUTABLE");

        bytes   memory code  = payloadAddress.code;
        bytes32 bytecodeHash = keccak256(code);

        vm.prank(Ethereum.PAUSE_PROXY);
        IStarGuardLike(Ethereum.GROVE_STAR_GUARD).plot({
            addr_ : payloadAddress,
            tag_  : bytecodeHash
        });

        address returnedPayloadAddress = IStarGuardLike(Ethereum.GROVE_STAR_GUARD).exec();

        require(payloadAddress == returnedPayloadAddress, "FAILED TO EXECUTE PAYLOAD");
        chainData[ChainIdUtils.Ethereum()].spellExecuted = true;
    }

    function _clearLogs() internal {
        RecordedLogs.clearLogs();

        // Need to also reset all bridge indicies
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            for (uint256 j = 0; j < chainData[chainId].bridges.length ; j++){
                chainData[chainId].bridges[j].lastSourceLogIndex = 0;
                chainData[chainId].bridges[j].lastDestinationLogIndex = 0;
            }
        }
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

}
