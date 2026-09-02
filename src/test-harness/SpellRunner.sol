// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test }      from "forge-std/Test.sol";
import { StdChains } from "forge-std/StdChains.sol";
import { Vm }        from "forge-std/Vm.sol";
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

    string  private constant PROPOSALS_DIR = "src/proposals";
    uint256 private constant NOT_FOUND     = type(uint256).max; // vm.indexOf miss sentinel

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

        uint256 timestamp = vm.parseUint(timestampString);

        for (uint256 i = 0; i < chainIds.length; ++i) {
            blocks[i] = _readBlockCache(chainIds[i], timestamp);
            if (blocks[i] != 0) {
                console.log(string(abi.encodePacked("Resolved ", chainIds[i].toDomainString(), " block from cache:")), blocks[i]);
                continue;
            }

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

            string memory response;
            bool statusOk;

            // Etherscan free tier is limited to 5 calls/second and test contracts run
            // in parallel, so back off and retry on a failed status before failing hard
            for (uint256 attempt = 0; attempt < 10; ++attempt) {
                if (attempt > 0) vm.sleep(1000);

                response = string(vm.ffi(curlCmd));
                // Result: {"status":"1","message":"OK","result":"18518418"}
                if (!vm.keyExistsJson(response, ".status")) continue;

                if (keccak256(bytes(vm.parseJsonString(response, ".status"))) == keccak256(bytes("1"))) {
                    statusOk = true;
                    break;
                }
            }

            require(
                statusOk,
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

            _writeBlockCache(chainIds[i], timestamp, blocks[i]);
            console.log(string(abi.encodePacked("Resolved ", chainIds[i].toDomainString(), " block from Etherscan:")), blocks[i]);
        }
    }

    /// @dev Find the first block with a timestamp at or after 'searchTimestamp' by
    /// binary-searching fork timestamps (matching the 'closest=after' semantics of the
    /// Etherscan queries in getBlocksFromDateByChainIds). The search window is grown
    /// automatically, so arbitrarily old dates work regardless of chain block times.
    /// Used for chains not covered by Etherscan's block-by-timestamp API.
    function getBlockFromTimestampBinarySearch(ChainId chainId, uint256 searchTimestamp) internal returns (uint256 bestBlock) {
        bestBlock = _readBlockCache(chainId, searchTimestamp);
        if (bestBlock != 0) {
            console.log(string(abi.encodePacked("Resolved ", chainId.toDomainString(), " block from cache:")), bestBlock);
            return bestBlock;
        }

        string memory rpcUrl = getChain(ChainId.unwrap(chainId)).rpcUrl;

        // The search selects throwaway forks; restore the caller's fork (if any) on exit.
        // vm.activeFork() reverts when no fork is active, e.g. during setupBlocksFromDate
        uint256 originalFork = type(uint256).max;
        try vm.activeFork() returns (uint256 forkId) { originalFork = forkId; } catch {}

        vm.createSelectFork(rpcUrl);

        require(block.timestamp >= searchTimestamp, "SpellRunner/timestamp-in-the-future");

        uint256 endBlock = block.number;

        // Double the window until its start block is earlier than the target timestamp
        uint256 window = 1_000_000;
        uint256 startBlock;
        while (true) {
            startBlock = window < endBlock ? endBlock - window : 0;
            vm.createSelectFork(rpcUrl, startBlock);
            if (block.timestamp < searchTimestamp) break;
            require(startBlock > 0, "SpellRunner/timestamp-before-genesis");
            window *= 2;
        }

        bestBlock = endBlock;

        while (startBlock <= endBlock) {
            uint256 midBlock = (startBlock + endBlock) / 2;

            vm.createSelectFork(rpcUrl, midBlock);

            if (block.timestamp >= searchTimestamp) {
                bestBlock = midBlock;
                endBlock  = midBlock - 1;
            } else {
                startBlock = midBlock + 1;
            }
        }

        // Guards against inconsistent timestamps served by load-balanced RPC nodes
        vm.createSelectFork(rpcUrl, bestBlock - 1);
        require(block.timestamp < searchTimestamp, "SpellRunner/inconsistent-rpc-timestamps");

        _writeBlockCache(chainId, searchTimestamp, bestBlock);
        console.log(string(abi.encodePacked("Resolved ", chainId.toDomainString(), " block by binary search:")), bestBlock);

        if (originalFork != type(uint256).max) vm.selectFork(originalFork);
    }

    // A past timestamp always maps to the same block, and setUp() (hence block resolution)
    // runs before every single test function, so results are memoized on disk to keep both
    // the binary searches and the Etherscan queries to one per chain and date
    string internal constant BLOCK_CACHE_DIR = "cache/fork-blocks/";

    function _blockCachePath(ChainId chainId, uint256 timestamp) private view returns (string memory) {
        return string(abi.encodePacked(BLOCK_CACHE_DIR, vm.toString(ChainId.unwrap(chainId)), "-", vm.toString(timestamp)));
    }

    function _readBlockCache(ChainId chainId, uint256 timestamp) private view returns (uint256) {
        string memory path = _blockCachePath(chainId, timestamp);
        if (!vm.exists(path)) return 0;

        // Treat empty or non-numeric content (e.g. a torn concurrent write) as a cache
        // miss instead of reverting; the re-resolved value then overwrites the bad entry
        bytes memory content = bytes(vm.readFile(path));
        if (content.length == 0) return 0;
        for (uint256 i = 0; i < content.length; ++i) {
            if (content[i] < "0" || content[i] > "9") return 0;
        }

        return vm.parseUint(string(content));
    }

    function _writeBlockCache(ChainId chainId, uint256 timestamp, uint256 blockNumber) private {
        vm.createDir(BLOCK_CACHE_DIR, true);
        vm.writeFile(_blockCachePath(chainId, timestamp), vm.toString(blockNumber));
    }

    function isoToUnix(string memory iso) internal returns (string memory) {
        // Build a bash script that works on both GNU date (Linux) and BSD date (macOS).
        // Run it with -c, never -lc: a login shell sources profile files, and anything they
        // print lands on stdout ahead of the result and corrupts it.
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
        cmd[1] = "-c";
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

    /// @dev Yesterday's UTC midnight, as an ISO string `setupDomains` accepts. Suites
    /// that track current chain state resolve their fork date through this instead of
    /// hardcoding a literal that silently ages. Rounding to a day boundary keeps the
    /// fork block stable within a day so the block cache still hits, and the 24h lag
    /// keeps the block indexed by the block-by-timestamp APIs.
    ///
    /// Call this once per suite run. `setUp` runs once and every test replays from the
    /// post-`setUp` snapshot, so calling it there gives the whole run one fork date even
    /// when the run crosses UTC midnight.
    function previousUtcMidnight() internal returns (string memory) {
        // Same GNU/BSD split as isoToUnix; printf avoids a trailing newline
        string memory sh = string.concat(
            "printf '%s' \"$(",
                "if date --version >/dev/null 2>&1; then ",
                    "date -u -d 'yesterday' +%Y-%m-%dT00:00:00Z; ",
                "else ",
                    "date -u -v-1d +%Y-%m-%dT00:00:00Z; ",
                "fi",
            ")\""
        );

        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = sh;

        return string(vm.ffi(cmd));
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

        // Plume and Robinhood are not covered by Etherscan's block-by-timestamp API,
        // so their blocks are found by binary-searching fork timestamps instead
        uint256 timestamp      = vm.parseUint(isoToUnix(date));
        uint256 plumeBlock     = getBlockFromTimestampBinarySearch(ChainIdUtils.Plume(),     timestamp);
        uint256 robinhoodBlock = getBlockFromTimestampBinarySearch(ChainIdUtils.Robinhood(), timestamp);

        chainData[ChainIdUtils.Ethereum()].domain  = getChain("mainnet").createFork(blocks[0]);
        chainData[ChainIdUtils.Avalanche()].domain = getChain("avalanche").createFork(blocks[1]);
        chainData[ChainIdUtils.Base()].domain      = getChain("base").createFork(blocks[2]);
        chainData[ChainIdUtils.Plume()].domain     = getChain("plume").createFork(plumeBlock);
        chainData[ChainIdUtils.Robinhood()].domain = getChain("robinhood").createFork(robinhoodBlock);

        console.log("   Mainnet block:", blocks[0]);
        console.log(" Avalanche block:", blocks[1]);
        console.log("      Base block:", blocks[2]);
        console.log("     Plume block:", plumeBlock);
        console.log(" Robinhood block:", robinhoodBlock);
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

    /// @dev True when a spell cycle is present in src/proposals. Detection is by file rather
    /// than by configured payload so that a cycle whose payload never loaded, from a
    /// misnamed file or a stale artifact, is told apart from an idle repo between cycles.
    function _spellSuiteInFlight() internal view returns (bool) {
        return _proposalSolidityFileExists("");
    }

    /// @dev True when src/proposals holds a Solidity file for this chain, matched on the same
    /// `Grove<Domain>_` prefix that spellIdentifier derives artifact names from. A chain is
    /// only expected to configure a payload when its cycle ships one of these.
    function _spellFileExists(ChainId chainId) internal view returns (bool) {
        return _proposalSolidityFileExists(string.concat("/Grove", chainId.toDomainString(), "_"));
    }

    function _proposalSolidityFileExists(string memory pathFragment) private view returns (bool) {
        // Absent between cycles: git tracks no files under src/proposals once one is archived
        if (!vm.isDir(PROPOSALS_DIR)) return false;

        Vm.DirEntry[] memory entries = vm.readDir(PROPOSALS_DIR, 3);

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].isDir)                        continue;
            if (!_hasSolidityExtension(entries[i].path)) continue;
            if (bytes(pathFragment).length == 0)         return true;

            if (vm.indexOf(entries[i].path, pathFragment) != NOT_FOUND) return true;
        }

        return false;
    }

    function _hasSolidityExtension(string memory path) private pure returns (bool) {
        bytes memory chars = bytes(path);
        if (chars.length < 4) return false;

        return chars[chars.length - 4] == "."
            && chars[chars.length - 3] == "s"
            && chars[chars.length - 2] == "o"
            && chars[chars.length - 1] == "l";
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
        // GroveStateTests tracks live chain state and configures no payload, so there is
        // nothing to execute, relay, or forward. Every cycle ships a mainnet payload, so
        // reaching here with proposal files present means the suite is misconfigured
        // rather than idle, and must keep failing instead of asserting pre-execution state.
        if (chainData[ChainIdUtils.Ethereum()].payload == address(0)) {
            require(!_spellSuiteInFlight(), "SPELL IN FLIGHT BUT NO MAINNET PAYLOAD CONFIGURED");
            console.log("No mainnet payload configured - skipping spell execution");
            return;
        }

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
