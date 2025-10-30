// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test }      from "forge-std/Test.sol";
import { StdChains } from "forge-std/StdChains.sol";
import { console }   from "forge-std/console.sol";

import { Ethereum }  from 'grove-address-registry/Ethereum.sol';
import { Avalanche } from 'grove-address-registry/Avalanche.sol';
import { Base }      from 'grove-address-registry/Base.sol';
import { Plasma }    from 'grove-address-registry/Plasma.sol';
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

import { GrovePayloadEthereum }  from "../libraries/payloads/GrovePayloadEthereum.sol";

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

    /// @dev maximum 3 chains in 1 query
    function getBlocksFromDate(string memory date, string[] memory chains) internal returns (uint256[] memory blocks) {
        blocks = new uint256[](chains.length);

        // Process chains in batches of 3
        for (uint256 batchStart; batchStart < chains.length; batchStart += 3) {
            uint256 batchSize = chains.length - batchStart < 3 ? chains.length - batchStart : 3;
            string[] memory batchChains = new string[](batchSize);

            // Create batch of chains
            for (uint256 i = 0; i < batchSize; i++) {
                batchChains[i] = chains[batchStart + i];
            }

            // Build networks parameter for this batch
            string memory networks = "";
            for (uint256 i = 0; i < batchSize; i++) {
                if (i == 0) {
                    networks = string(abi.encodePacked("networks=", batchChains[i]));
                } else {
                    networks = string(abi.encodePacked(networks, "&networks=", batchChains[i]));
                }
            }

            string[] memory inputs = new string[](8);
            inputs[0] = "curl";
            inputs[1] = "-s";
            inputs[2] = "--request";
            inputs[3] = "GET";
            inputs[4] = "--url";
            inputs[5] = string(abi.encodePacked("https://api.g.alchemy.com/data/v1/", vm.envString("ALCHEMY_API_KEY"), "/utility/blocks/by-timestamp?", networks, "&timestamp=", date, "&direction=AFTER"));
            inputs[6] = "--header";
            inputs[7] = "accept: application/json";

            string memory response = string(vm.ffi(inputs));

            // Store results in the correct positions of the final blocks array
            for (uint256 i = 0; i < batchSize; i++) {
                blocks[batchStart + i] = vm.parseJsonUint(response, string(abi.encodePacked(".data[", vm.toString(i), "].block.number")));
            }
        }
    }

    function setupBlocksFromDate(string memory date) internal {
        setChain("plasma", ChainData({
            name: "Plasma",
            rpcUrl: vm.envString("PLASMA_RPC_URL"),
            chainId: 9745
        }));
        setChain("plume", ChainData({
            name: "Plume",
            rpcUrl: vm.envString("PLUME_RPC_URL"),
            chainId: 98866
        }));

        string[] memory chains = new string[](5);
        chains[0] = "eth-mainnet";
        chains[1] = "avax-mainnet";
        chains[2] = "base-mainnet";
        // Not used for now, but API requires at least 5 chains in a single request
        chains[3] = "arb-mainnet"; // Not used
        chains[4] = "opt-mainnet"; // Not used

        uint256[] memory blocks = getBlocksFromDate(date, chains);

        chainData[ChainIdUtils.Ethereum()].domain  = getChain("mainnet").createFork(blocks[0]);
        chainData[ChainIdUtils.Avalanche()].domain = getChain("avalanche").createFork(blocks[1]);
        chainData[ChainIdUtils.Base()].domain      = getChain("base").createFork(blocks[2]);

        uint256[] memory hardcodedBlocks = new uint256[](2);
        hardcodedBlocks[0] = 4738720;  // Plasma
        hardcodedBlocks[1] = 30242550; // Plume

        chainData[ChainIdUtils.Plasma()].domain = getChain("plasma").createFork(hardcodedBlocks[0]);
        chainData[ChainIdUtils.Plume()].domain  = getChain("plume").createFork(hardcodedBlocks[1]);

        console.log("   Mainnet block:", blocks[0]);
        console.log(" Avalanche block:", blocks[1]);
        console.log("      Base block:", blocks[2]);
        console.log("    Plasma block:", hardcodedBlocks[0]);
        console.log("     Plume block:", hardcodedBlocks[1]);
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

        chainData[ChainIdUtils.Plasma()].executor       = IExecutor(Plasma.GROVE_EXECUTOR);
        chainData[ChainIdUtils.Plasma()].prevController = Plasma.ALM_CONTROLLER;
        chainData[ChainIdUtils.Plasma()].newController  = Plasma.ALM_CONTROLLER;

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

        // Plasma
        chainData[ChainIdUtils.Plasma()].bridges.push(
            LZBridgeTesting.createLZBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Plasma()].domain
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
        allChains.push(ChainIdUtils.Plasma());
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
        _relayMessageOverBridges();
        // execute the foreign payloads (either by simulation or real execute)
        _executeForeignPayloads();
    }

    /// @dev bridge contracts themselves are stored on mainnet
    function _relayMessageOverBridges() internal onChain(ChainIdUtils.Ethereum()) {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
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
        } else if (bridge.bridgeType == BridgeType.LZ) {
            LZBridgeTesting.relayMessagesToDestination(bridge, false, Ethereum.GROVE_PROXY, Plasma.GROVE_RECEIVER); // TODO: Fix, make chain agnostic
        }
    }

    function _executeForeignPayloads() private onChain(ChainIdUtils.Ethereum()) {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            if (chainId == ChainIdUtils.Ethereum()) continue;  // Don't execute mainnet

            // UNCOMMENT AFTER OTHER DOMAINS ARE SET UP
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
        if (chainId == ChainIdUtils.Plasma())    return spell.PAYLOAD_PLASMA();
        if (chainId == ChainIdUtils.Plume())     return spell.PAYLOAD_PLUME();

        revert("Unsupported chainId");
    }

    function executeMainnetPayload() internal onChain(ChainIdUtils.Ethereum()) {
        address payloadAddress = chainData[ChainIdUtils.Ethereum()].payload;
        IExecutor executor     = chainData[ChainIdUtils.Ethereum()].executor;
        require(_isContract(payloadAddress), "PAYLOAD IS NOT A CONTRACT");

        vm.prank(Ethereum.PAUSE_PROXY);
        (bool success,) = address(executor).call(abi.encodeWithSignature(
            'exec(address,bytes)',
            payloadAddress,
            abi.encodeWithSignature('execute()')
        ));
        require(success, "FAILED TO EXECUTE PAYLOAD");
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
