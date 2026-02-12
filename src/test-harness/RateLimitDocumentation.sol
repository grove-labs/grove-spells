// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { ChainId, ChainIdUtils }      from "src/libraries/helpers/ChainId.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

/**
 * @title  RateLimitDocumentation
 * @notice Utility for capturing and documenting rate limits set by spells
 * @dev    Captures RateLimitDataSet events and attempts to auto-label them
 */
abstract contract RateLimitDocumentation is Test {

    /**********************************************************************************************/
    /*** Enums                                                                                  ***/
    /**********************************************************************************************/

    enum KeyType {
        Simple,           // No encoding needed beyond the hash itself
        Asset,            // keccak256(abi.encode(bytes32, address))
        AssetDestination, // keccak256(abi.encode(bytes32, address, address))
        Domain            // keccak256(abi.encode(bytes32, uint32))
    }

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct RegisteredAddress {
        address addr;
        string  label;
    }

    struct LimitType {
        bytes32 hash;
        string  label;
        KeyType keyType;
    }

    struct CapturedRateLimit {
        bytes32 key;
        uint256 maxAmount;
        uint256 slope;
        string  label;
    }

    /**********************************************************************************************/
    /*** Storage                                                                                ***/
    /**********************************************************************************************/

    RegisteredAddress[] internal _registeredAddresses;
    LimitType[]         internal _limitTypes;
    address[]           internal _extractedAddresses; // Addresses extracted from logs during execution

    bool internal _limitTypesInitialized;

    /**********************************************************************************************/
    /*** Events (for matching)                                                                  ***/
    /**********************************************************************************************/

    event RateLimitDataSet(
        bytes32 indexed key,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    );

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    function _initializeLimitTypes() internal {
        if (_limitTypesInitialized) return;
        _limitTypesInitialized = true;

        // Simple keys (no encoding needed beyond the hash itself)
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_USDS_MINT,    "USDS_MINT",    KeyType.Simple));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_USDS_TO_USDC, "USDS_TO_USDC", KeyType.Simple));

        // Asset keys (keccak256(abi.encode(limitType, asset)))
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,   "4626_DEPOSIT",   KeyType.Asset));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_4626_WITHDRAW,  "4626_WITHDRAW",  KeyType.Asset));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_7540_DEPOSIT,   "7540_DEPOSIT",   KeyType.Asset));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_7540_REDEEM,    "7540_REDEEM",    KeyType.Asset));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_AAVE_DEPOSIT,   "AAVE_DEPOSIT",   KeyType.Asset));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_AAVE_WITHDRAW,  "AAVE_WITHDRAW",  KeyType.Asset));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_CURVE_DEPOSIT,  "CURVE_DEPOSIT",  KeyType.Asset));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_CURVE_SWAP,     "CURVE_SWAP",     KeyType.Asset));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_CURVE_WITHDRAW, "CURVE_WITHDRAW", KeyType.Asset));

        // Asset-destination keys (keccak256(abi.encode(limitType, asset, destination)))
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_ASSET_TRANSFER,      "ASSET_TRANSFER",      KeyType.AssetDestination));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_SWAP,     "UNISWAP_V3_SWAP",     KeyType.AssetDestination));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_DEPOSIT,  "UNISWAP_V3_DEPOSIT",  KeyType.AssetDestination));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_UNISWAP_V3_WITHDRAW, "UNISWAP_V3_WITHDRAW", KeyType.AssetDestination));

        // Domain keys (keccak256(abi.encode(limitType, domain)))
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_USDC_TO_CCTP,   "USDC_TO_CCTP",   KeyType.Simple));
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_USDC_TO_DOMAIN, "USDC_TO_DOMAIN", KeyType.Domain));

        // Centrifuge transfer key (keccak256(abi.encode(limitType, vault, destId)))
        _limitTypes.push(LimitType(GroveLiquidityLayerHelpers.LIMIT_CENTRIFUGE_TRANSFER, "CENTRIFUGE_TRANSFER", KeyType.AssetDestination));
    }

    /**********************************************************************************************/
    /*** Registration Functions                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Register an address for key matching
     * @param addr  The address to register
     * @param label Human-readable label for the address
     */
    function _registerAddress(address addr, string memory label) internal {
        _registeredAddresses.push(RegisteredAddress(addr, label));
    }

    /**
     * @notice Override this function in spell tests to register addresses for rate limit documentation
     * @dev    Call _registerAddress(address, label) for each address used in the spell
     */
    function _registerAddressesForDocumentation() internal virtual {
        // Override in spell-specific test files
    }

    /**********************************************************************************************/
    /*** Main Documentation Function                                                            ***/
    /**********************************************************************************************/

    /**
     * @notice Execute spell for a specific chain, capture rate limit events, and print documentation
     * @param chainId The chain to capture rate limits for
     */
    function _printRateLimits(ChainId chainId) internal virtual {
        _initializeLimitTypes();

        // Start recording logs
        vm.recordLogs();

        // Execute the spell for the specified chain
        _executeSpellForDocumentation(chainId);

        // Get recorded logs immediately after spell execution
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Filter and process RateLimitDataSet events
        CapturedRateLimit[] memory captured = _processLogs(logs);

        // Print formatted output with chain name
        _printFormattedOutput(captured, chainId);
    }

    /**
     * @notice Override this to execute the spell for a specific chain
     * @param chainId The chain to execute the spell for
     */
    function _executeSpellForDocumentation(ChainId chainId) internal virtual;

    /**********************************************************************************************/
    /*** Log Processing                                                                         ***/
    /**********************************************************************************************/

    function _processLogs(Vm.Log[] memory logs) internal returns (CapturedRateLimit[] memory) {
        // First: extract all addresses from logs for later matching
        _extractAddressesFromLogs(logs);

        bytes32 eventSig = keccak256("RateLimitDataSet(bytes32,uint256,uint256,uint256,uint256)");

        // First pass: count matching events
        uint256 count = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == eventSig) {
                count++;
            }
        }

        // Second pass: extract data
        CapturedRateLimit[] memory captured = new CapturedRateLimit[](count);
        uint256 idx = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == eventSig) {
                // Key is indexed (topic[1])
                bytes32 key = logs[i].topics[1];

                // Decode non-indexed parameters from data
                (uint256 maxAmount, uint256 slope,,) = abi.decode(logs[i].data, (uint256, uint256, uint256, uint256));

                // Try to match the key to a known pattern
                string memory label = _matchKey(key);

                captured[idx] = CapturedRateLimit({
                    key:       key,
                    maxAmount: maxAmount,
                    slope:     slope,
                    label:     label
                });
                idx++;
            }
        }

        return captured;
    }

    /**
     * @notice Extract unique addresses from logs for later key matching
     * @dev    Extracts emitter addresses and addresses from indexed topics
     */
    function _extractAddressesFromLogs(Vm.Log[] memory logs) internal {
        delete _extractedAddresses;

        for (uint256 i = 0; i < logs.length; i++) {
            // Add emitter address
            _addUniqueAddress(logs[i].emitter);

            // Check indexed topics for addresses (topics[1], topics[2], topics[3])
            // Topics that look like zero-padded addresses (upper 12 bytes are 0)
            for (uint256 t = 1; t < logs[i].topics.length; t++) {
                bytes32 topic = logs[i].topics[t];
                // Check if upper 12 bytes are zero (address is 20 bytes, padded to 32)
                if (uint256(topic) <= type(uint160).max && uint256(topic) > 0) {
                    _addUniqueAddress(address(uint160(uint256(topic))));
                }
            }
        }
    }

    /**
     * @notice Add address to extracted list if not already present
     */
    function _addUniqueAddress(address addr) internal {
        // Skip zero address and common false positives (small numbers)
        if (addr == address(0) || uint160(addr) < 1000) return;

        // Check if already in list
        for (uint256 i = 0; i < _extractedAddresses.length; i++) {
            if (_extractedAddresses[i] == addr) return;
        }
        _extractedAddresses.push(addr);
    }

    /**********************************************************************************************/
    /*** Key Matching                                                                           ***/
    /**********************************************************************************************/

    function _matchKey(bytes32 key) internal view returns (string memory) {
        uint256 totalAddresses = _registeredAddresses.length + _extractedAddresses.length;

        for (uint256 i = 0; i < _limitTypes.length; i++) {
            LimitType memory lt = _limitTypes[i];

            if (lt.keyType == KeyType.Simple) {
                if (lt.hash == key) return lt.label;
            }
            else if (lt.keyType == KeyType.Asset) {
                for (uint256 j = 0; j < totalAddresses; j++) {
                    (address addr, string memory addrLabel) = _getAddressAndLabel(j);
                    if (keccak256(abi.encode(lt.hash, addr)) == key) {
                        return string.concat(lt.label, "(", addrLabel, ")");
                    }
                }
            }
            else if (lt.keyType == KeyType.AssetDestination) {
                string memory result = _tryAssetDestinationMatch(lt.hash, lt.label, key);
                if (bytes(result).length > 0) return result;
            }
            else if (lt.keyType == KeyType.Domain) {
                for (uint32 domain = 0; domain <= 10; domain++) {
                    if (keccak256(abi.encode(lt.hash, domain)) == key) {
                        return string.concat(lt.label, "(", vm.toString(uint256(domain)), ")");
                    }
                }
            }
        }

        return "UNKNOWN";
    }

    /**********************************************************************************************/
    /*** Output Formatting                                                                      ***/
    /**********************************************************************************************/

    function _printFormattedOutput(CapturedRateLimit[] memory captured, ChainId chainId) internal pure {
        // Header with chain name
        console.log("");
        console.log("=== Rate Limits Set by Spell [%s] ===", chainId.toDomainString());
        console.log("");

        if (captured.length == 0) {
            console.log("No rate limits were set.");
            return;
        }

        // Print each rate limit
        for (uint256 i = 0; i < captured.length; i++) {
            console.log("---");
            console.log("Label:      %s", captured[i].label);
            console.log("Key:        %s", vm.toString(captured[i].key));

            // Max amount - check for unlimited
            if (captured[i].maxAmount == type(uint256).max) {
                console.log("Max Amount: unlimited");
            } else {
                console.log("Max Amount: %s", vm.toString(captured[i].maxAmount));
            }

            // Slope: show stored value first, then daily rate in parentheses
            if (captured[i].slope == 0) {
                console.log("Slope:      0");
            } else if (captured[i].slope == type(uint256).max) {
                console.log("Slope:      unlimited");
            } else {
                console.log(
                    "Slope:      %s (%s / 1 day)",
                    vm.toString(captured[i].slope),
                    vm.toString(captured[i].slope * 1 days)
                );
            }
        }

        console.log("---");
        console.log("");
        console.log("Total rate limits set: %s", vm.toString(captured.length));
        console.log("");
    }

    /**********************************************************************************************/
    /*** Utility Functions                                                                      ***/
    /**********************************************************************************************/

    /**
     * @notice Try to match an asset-destination key against all known addresses
     * @param limitHash The limit type hash
     * @param limitLabel The limit type label
     * @param key The key to match
     * @return The label if matched, empty string otherwise
     */
    function _tryAssetDestinationMatch(
        bytes32 limitHash,
        string memory limitLabel,
        bytes32 key
    ) internal view returns (string memory) {
        // Total addresses from all sources: registered + extracted
        uint256 totalAddresses = _registeredAddresses.length + _extractedAddresses.length;

        for (uint256 j = 0; j < totalAddresses; j++) {
            (address addrJ, string memory labelJ) = _getAddressAndLabel(j);

            for (uint256 k = 0; k < totalAddresses; k++) {
                (address addrK, string memory labelK) = _getAddressAndLabel(k);

                bytes32 computed = keccak256(abi.encode(limitHash, addrJ, addrK));
                if (computed == key) {
                    return string.concat(limitLabel, "(", labelJ, " -> ", labelK, ")");
                }
            }
        }

        return "";
    }

    /**
     * @notice Get address and label from combined index across all address sources
     * @param idx Index into combined list (registered, then extracted)
     * @return addr The address
     * @return label The label (custom for registered, hex for extracted)
     */
    function _getAddressAndLabel(uint256 idx) internal view returns (address addr, string memory label) {
        if (idx < _registeredAddresses.length) {
            addr = _registeredAddresses[idx].addr;
            label = _registeredAddresses[idx].label;
        } else {
            addr = _extractedAddresses[idx - _registeredAddresses.length];
            label = vm.toString(addr);
        }
    }

}
