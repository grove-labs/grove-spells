// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test }      from "forge-std/Test.sol";
import { StdChains } from "forge-std/StdChains.sol";
import { console }   from "forge-std/console.sol";

import { Ethereum }  from 'grove-address-registry/Ethereum.sol';
import { Avalanche } from 'grove-address-registry/Avalanche.sol';
import { Base }      from 'grove-address-registry/Base.sol';
import { Plume }     from 'grove-address-registry/Plume.sol';
import { Robinhood } from 'grove-address-registry/Robinhood.sol';

import { IExecutor } from 'lib/grove-gov-relay/src/interfaces/IExecutor.sol';

import { Bridge, BridgeType }    from "xchain-helpers/testing/Bridge.sol";
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { RecordedLogs }          from "xchain-helpers/testing/utils/RecordedLogs.sol";

import { OptimismBridgeTesting } from "xchain-helpers/testing/bridges/OptimismBridgeTesting.sol";
import { AMBBridgeTesting }      from "xchain-helpers/testing/bridges/AMBBridgeTesting.sol";
import { ArbitrumBridgeTesting } from "xchain-helpers/testing/bridges/ArbitrumBridgeTesting.sol";
import { CCTPBridgeTesting }     from "xchain-helpers/testing/bridges/CCTPBridgeTesting.sol";
import { CCTPv2BridgeTesting }   from "xchain-helpers/testing/bridges/CCTPv2BridgeTesting.sol";
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

    struct LZOftPair {
        address sourceOft;
        address destinationOft;
    }

    mapping(ChainId => DomainData)   internal chainData;
    mapping(ChainId => LZOftPair[])  internal lzOftPairs;
    mapping(ChainId => uint256)      internal foreignActionsSetCountBefore;

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
        string memory urlBase         = "https://api.etherscan.io/v2/api?";
        string memory apiKeyEnv       = "ETHERSCAN_API_KEY";
        string memory apiKey          = vm.envString(apiKeyEnv);

        for (uint256 i = 0; i < chainIds.length; ++i) {
            string memory chainId = vm.toString(ChainId.unwrap(chainIds[i]));

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
            string memory status = vm.parseJsonString(response, ".status");
            require(
                keccak256(bytes(status)) == keccak256(bytes("1")),
                string(abi.encodePacked(
                    "SpellRunner/etherscan-failed chainId=",
                    chainId,
                    " response=",
                    response
                ))
            );

            blocks[i] = vm.parseJsonUint(response, ".result");
            require(
                blocks[i] > 0,
                string(abi.encodePacked("SpellRunner/invalid-block chainId=", chainId))
            );
        }
    }

    function isoToUnix(string memory iso) internal returns (string memory) {
        // Build a bash script that works on both GNU date (Linux) and BSD date (macOS)
        string memory sh = string.concat(
            "ISO='", iso, "'; ",
            "if date --version >/dev/null 2>&1; then ",
                "date -d \"$ISO\" +%s; ",
            "else ",
                "TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%SZ' \"$ISO\" +%s; ",
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

    function setupBlocksFromDate(string memory date) internal {
        setChain("plume", ChainData({
            name    : "Plume",
            rpcUrl  : vm.envString("PLUME_RPC_URL"),
            chainId : 98866
        }));

        setChain("robinhood", ChainData({
            name    : "Robinhood",
            rpcUrl  : vm.envString("ROBINHOOD_RPC_URL"),
            chainId : 4663
        }));

        ChainId[] memory chainIds = new ChainId[](3);
        chainIds[0] = ChainIdUtils.Ethereum();
        chainIds[1] = ChainIdUtils.Avalanche();
        chainIds[2] = ChainIdUtils.Base();

        uint256[] memory blocks = getBlocksFromDateByChainIds(date, chainIds);

        chainData[ChainIdUtils.Ethereum()].domain  = getChain("mainnet").createFork(blocks[0]);
        chainData[ChainIdUtils.Avalanche()].domain = getChain("avalanche").createFork(blocks[1]);
        chainData[ChainIdUtils.Base()].domain      = getChain("base").createFork(blocks[2]);

        uint256[] memory hardcodedBlocks = new uint256[](2);
        hardcodedBlocks[0] = 42727304; // Plume
        hardcodedBlocks[1] = 4502920;  // Robinhood

        chainData[ChainIdUtils.Plume()].domain     = getChain("plume").createFork(hardcodedBlocks[0]);
        chainData[ChainIdUtils.Robinhood()].domain = getChain("robinhood").createFork(hardcodedBlocks[1]);

        console.log("   Mainnet block:", blocks[0]);
        console.log(" Avalanche block:", blocks[1]);
        console.log("      Base block:", blocks[2]);
        console.log("     Plume block:", hardcodedBlocks[0]);
        console.log(" Robinhood block:", hardcodedBlocks[1]);
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

        chainData[ChainIdUtils.Robinhood()].executor       = IExecutor(Robinhood.GROVE_EXECUTOR);
        chainData[ChainIdUtils.Robinhood()].prevController = Robinhood.ALM_CONTROLLER;
        chainData[ChainIdUtils.Robinhood()].newController  = Robinhood.ALM_CONTROLLER;

        // Avalanche
        chainData[ChainIdUtils.Avalanche()].bridges.push(
            CCTPBridgeTesting.createCircleBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Avalanche()].domain
            )
        );
        chainData[ChainIdUtils.Avalanche()].bridges.push(
            CCTPv2BridgeTesting.createCircleBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Avalanche()].domain
            )
        );
        chainData[ChainIdUtils.Avalanche()].bridges.push(
            LZBridgeTesting.createLZBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Avalanche()].domain
            )
        );
        // USDS SkyLink OFT (Ethereum <-> Avalanche)
        lzOftPairs[ChainIdUtils.Avalanche()].push(LZOftPair(
            Ethereum.USDS_SKYLINK_OFT,  // USDS OFT Ethereum
            Avalanche.USDS_SKYLINK_OFT  // USDS OFT Avalanche
        ));

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
        chainData[ChainIdUtils.Base()].bridges.push(
            CCTPv2BridgeTesting.createCircleBridge(
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
        chainData[ChainIdUtils.Plume()].bridges.push(
            CCTPv2BridgeTesting.createCircleBridge(
                chainData[ChainIdUtils.Ethereum()].domain,
                chainData[ChainIdUtils.Plume()].domain
            )
        );

        // Robinhood
        chainData[ChainIdUtils.Robinhood()].bridges.push(
            ArbitrumBridgeTesting.init(Bridge({
                bridgeType                     : BridgeType.ARBITRUM,
                source                         : chainData[ChainIdUtils.Ethereum()].domain,
                destination                    : chainData[ChainIdUtils.Robinhood()].domain,
                sourceCrossChainMessenger      : 0x1A07cc4BD17E0118BdB54D70990D2158AbAD7a2D, // Robinhood L1 bridge (Delayed Inbox)
                destinationCrossChainMessenger : 0x0000000000000000000000000000000000000064, // ArbSys precompile
                lastSourceLogIndex             : 0,
                lastDestinationLogIndex        : 0,
                extraData                      : ""
            }))
        );

        allChains.push(ChainIdUtils.Ethereum());
        allChains.push(ChainIdUtils.Avalanche());
        allChains.push(ChainIdUtils.Base());
        allChains.push(ChainIdUtils.Plume());
        allChains.push(ChainIdUtils.Robinhood());
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
        uint256 originalFork = vm.activeFork();
        // record foreign action set counts pre-relay so we can assert the relay
        // queued exactly one new set per chain before executing it
        _snapshotForeignActionsSetCounts();
        // only execute mainnet payload
        executeMainnetPayload();
        // then use bridges to execute other chains' payloads
        _relayMessageOverBridges(allChains);
        // execute the foreign payloads (either by simulation or real execute)
        _executeForeignPayloads();
        if (vm.activeFork() != originalFork) vm.selectFork(originalFork);
    }

    function _snapshotForeignActionsSetCounts() private {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            if (chainId == ChainIdUtils.Ethereum()) continue;

            chainData[chainId].domain.selectFork();
            foreignActionsSetCountBefore[chainId] = chainData[chainId].executor.actionsSetCount();
        }

        chainData[ChainIdUtils.Ethereum()].domain.selectFork();
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
        } else if (bridge.bridgeType == BridgeType.CCTP_V2) {
            CCTPv2BridgeTesting.relayMessagesToDestination(bridge, false);
            CCTPv2BridgeTesting.relayMessagesToSource(bridge, false);
        } else if (bridge.bridgeType == BridgeType.AMB) {
            AMBBridgeTesting.relayMessagesToDestination(bridge, false);
        } else if (bridge.bridgeType == BridgeType.ARBITRUM) {
            ArbitrumBridgeTesting.relayMessagesToDestination(bridge, false);
        } else if (bridge.bridgeType == BridgeType.LZ) {
            ChainId destChainId = ChainIdUtils.fromDomain(bridge.destination);
            LZOftPair[] storage pairs = lzOftPairs[destChainId];
            for (uint256 i = 0; i < pairs.length; i++) {
                LZBridgeTesting.relayMessagesToDestination(bridge, false, pairs[i].sourceOft, pairs[i].destinationOft);
                LZBridgeTesting.relayMessagesToSource(bridge, false, pairs[i].destinationOft, pairs[i].sourceOft);
            }
        }
    }

    function _executeForeignPayloads() private onChain(ChainIdUtils.Ethereum()) {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            if (chainId == ChainIdUtils.Ethereum()) continue;  // Don't execute mainnet

            address mainnetSpellPayload = _getForeignPayloadFromMainnetSpell(chainId);
            IExecutor executor = chainData[chainId].executor;
            if (mainnetSpellPayload != address(0)) {
                chainData[chainId].domain.selectFork();
                uint256 prevCount    = foreignActionsSetCountBefore[chainId];
                uint256 currentCount = executor.actionsSetCount();
                require(
                    currentCount == prevCount + 1,
                    string(abi.encodePacked(
                        "SpellRunner/relay-did-not-queue network=",
                        chainId.toDomainString()
                    ))
                );

                uint256 actionsSetId = currentCount - 1;
                // Stay at executionTime afterwards: warping back would put rate limits set during
                // execution (lastUpdated = executionTime) in the future of a delayed executor's
                // fork, underflowing getCurrentRateLimit(); no-op for zero-delay executors.
                vm.warp(executor.getActionsSetById(actionsSetId).executionTime);
                executor.execute(actionsSetId);
                chainData[chainId].spellExecuted = true;
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
        if (chainId == ChainIdUtils.Robinhood()) return spell.PAYLOAD_ROBINHOOD();

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
