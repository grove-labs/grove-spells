// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { VmSafe }  from "forge-std/Vm.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { ChainId, ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { CommonALMTestBase } from "./CommonALMTestBase.sol";
import { CommonPauTestBase } from "./CommonPauTestBase.sol";

/// @dev The kind of integration a rate limit key belongs to. Nothing dispatches on this
/// yet; it is what the per-category end-to-end runners will switch over once they land.
enum Category {
    AAVE,
    BASIN,
    CCTP,
    CENTRIFUGE,
    CORE,
    CURVE_LP,
    ERC4626,
    ETHENA,
    LAYERZERO,
    PSM,
    TRANSFER_ASSET,
    UNISWAP_V3
}

/// @dev A single onboarded integration and the rate limit keys that govern it. Entry keys
/// move funds in, exit keys move them out; an integration may use fewer than four.
/// 'asset' is the token the limits are denominated in, whose decimals scale the sanity
/// bounds. Zero means the denomination is not a single token, in which case 18 is assumed.
struct RateLimitIntegration {
    string   label;
    Category category;
    address  integration;
    address  asset;
    bytes32  entryId;
    bytes32  entryId2;
    bytes32  exitId;
    bytes32  exitId2;
    bytes    extraData;
}

/// @dev Discovers the rate limit keys that are live on chain by replaying every
/// RateLimitDataSet event, rather than trusting a hardcoded list. Both the legacy ALM
/// controller and the PAU diamond declare an identical event, so one topic covers both.
abstract contract CommonRateLimitTests is CommonALMTestBase, CommonPauTestBase {

    bytes32 internal constant RATE_LIMIT_DATA_SET =
        keccak256("RateLimitDataSet(bytes32,uint256,uint256,uint256,uint256)");

    uint256 internal constant ETHERSCAN_PAGE_SIZE = 1000;

    function _almIntegrations() internal view virtual returns (RateLimitIntegration[] memory);
    function _pauIntegrations() internal view virtual returns (RateLimitIntegration[] memory);

    function test_ETHEREUM_AlmRateLimitsRegistered() public onChain(ChainIdUtils.Ethereum()) {
        _testRateLimits(address(_getGroveLiquidityLayerContext(ChainIdUtils.Ethereum()).rateLimits), _almIntegrations());
    }

    function test_ETHEREUM_PauRateLimitsRegistered() public onChain(ChainIdUtils.Ethereum()) {
        _testRateLimits(address(_getPauContext(ChainIdUtils.Ethereum()).rateLimits), _pauIntegrations());
    }

    function test_AVALANCHE_RateLimitsRegistered() public onChain(ChainIdUtils.Avalanche()) {
        _testRateLimits(address(_getGroveLiquidityLayerContext(ChainIdUtils.Avalanche()).rateLimits), _almIntegrations());
    }

    function test_BASE_RateLimitsRegistered() public onChain(ChainIdUtils.Base()) {
        _testRateLimits(address(_getGroveLiquidityLayerContext(ChainIdUtils.Base()).rateLimits), _almIntegrations());
    }

    function test_PLUME_RateLimitsRegistered() public onChain(ChainIdUtils.Plume()) {
        _testRateLimits(address(_getGroveLiquidityLayerContext(ChainIdUtils.Plume()).rateLimits), _almIntegrations());
    }

    function test_ROBINHOOD_RateLimitsRegistered() public onChain(ChainIdUtils.Robinhood()) {
        _testRateLimits(address(_getGroveLiquidityLayerContext(ChainIdUtils.Robinhood()).rateLimits), _almIntegrations());
    }

    /// @dev Asserts every rate limit live on 'rateLimits' is registered, and that each
    /// registered limit holds a plausible value.
    function _testRateLimits(address rateLimits, RateLimitIntegration[] memory integrations) internal {
        for (uint256 i; i < integrations.length; ++i) {
            _checkRateLimitValues(rateLimits, integrations[i]);
        }

        _checkRateLimitCoverage(integrations, _discoverRateLimitKeys(rateLimits));
    }

    /// @dev Replays every RateLimitDataSet event emitted by 'rateLimits' up to the forked
    /// block and returns the keys that are currently onboarded. A non-zero maxAmount
    /// onboards a key, a zero maxAmount offboards it, so the final state of the replay is
    /// the live set.
    function _discoverRateLimitKeys(address rateLimits) internal returns (bytes32[] memory keys) {
        VmSafe.EthGetLogs[] memory logs = _fetchRateLimitLogs(rateLimits);

        keys = new bytes32[](0);

        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length < 2) continue;

            ( uint256 maxAmount,,, ) = abi.decode(logs[i].data, (uint256, uint256, uint256, uint256));

            keys = maxAmount == 0
                ? _removeKey(keys, logs[i].topics[1])
                : _appendKey(keys, logs[i].topics[1]);
        }
    }

    /// @dev Etherscan v2 does not support every chain Grove deploys to, so chains it does
    /// not index are read straight from the fork RPC instead. Grove already applies the
    /// same split for block-by-timestamp lookups in SpellRunner.
    function _fetchRateLimitLogs(address rateLimits) internal returns (VmSafe.EthGetLogs[] memory logs) {
        ChainId chain = ChainIdUtils.fromUint(block.chainid);

        if (_etherscanSupportsChain(chain)) {
            return _fetchLogsEtherscan(rateLimits);
        }

        bytes32[] memory topics = new bytes32[](1);
        topics[0] = RATE_LIMIT_DATA_SET;

        return vm.eth_getLogs(0, block.number, rateLimits, topics);
    }

    function _etherscanSupportsChain(ChainId chain) internal pure returns (bool) {
        return chain != ChainIdUtils.Plume() && chain != ChainIdUtils.Robinhood();
    }

    /// @dev Pages through the Etherscan log API. Bounded at the forked block because the
    /// API reports up to the chain head, which runs ahead of the fork and would surface
    /// keys the forked state does not have.
    function _fetchLogsEtherscan(address rateLimits) internal returns (VmSafe.EthGetLogs[] memory logs) {
        logs = new VmSafe.EthGetLogs[](0);

        for (uint256 page = 1;; ++page) {
            VmSafe.EthGetLogs[] memory pageLogs = _fetchLogsEtherscanPage(rateLimits, page);

            logs = _concat(logs, pageLogs);

            if (pageLogs.length < ETHERSCAN_PAGE_SIZE) break;
        }
    }

    function _fetchLogsEtherscanPage(address rateLimits, uint256 page)
        internal returns (VmSafe.EthGetLogs[] memory logs)
    {
        string memory chainId = vm.toString(block.chainid);

        string memory url = string(
            abi.encodePacked(
                "https://api.etherscan.io/v2/api?",
                "chainId=", chainId,
                "&module=logs",
                "&action=getLogs",
                "&fromBlock=0",
                "&toBlock=", vm.toString(block.number),
                "&address=", vm.toString(rateLimits),
                "&topic0=", vm.toString(RATE_LIMIT_DATA_SET),
                "&page=", vm.toString(page),
                "&offset=", vm.toString(ETHERSCAN_PAGE_SIZE),
                "&apikey=", vm.envString("ETHERSCAN_API_KEY")
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
        bool          statusOk;

        // Etherscan free tier is limited to 5 calls/second and test contracts run
        // in parallel, so back off and retry on a failed status before failing hard
        for (uint256 attempt; attempt < 10; ++attempt) {
            if (attempt > 0) vm.sleep(1000);

            response = string(vm.ffi(curlCmd));

            if (!vm.keyExistsJson(response, ".status")) continue;

            string memory status = vm.parseJsonString(response, ".status");

            // An empty page reports status "0" with "No records found", which is terminal
            if (keccak256(bytes(status)) == keccak256(bytes("0"))) {
                if (_isNoRecords(response)) return new VmSafe.EthGetLogs[](0);
                continue;
            }

            statusOk = true;
            break;
        }

        require(
            statusOk,
            string(abi.encodePacked(
                "CommonRateLimitTests/etherscan-failed chainId=", chainId, " response=", response
            ))
        );

        return _parseEtherscanLogs(response);
    }

    function _isNoRecords(string memory response) private view returns (bool) {
        return keccak256(bytes(vm.parseJsonString(response, ".message"))) == keccak256(bytes("No records found"));
    }

    function _parseEtherscanLogs(string memory response)
        private view returns (VmSafe.EthGetLogs[] memory logs)
    {
        uint256 count;

        while (vm.keyExistsJson(response, string(abi.encodePacked(".result[", vm.toString(count), "].address")))) {
            ++count;
        }

        logs = new VmSafe.EthGetLogs[](count);

        for (uint256 i; i < count; ++i) {
            string memory entry = string(abi.encodePacked(".result[", vm.toString(i), "]"));

            logs[i].topics = vm.parseJsonBytes32Array(response, string(abi.encodePacked(entry, ".topics")));
            logs[i].data   = vm.parseJsonBytes(response,        string(abi.encodePacked(entry, ".data")));
        }
    }

    /// @dev Rate limit keys are the hash of a limit name over its arguments. Both
    /// controllers encode identically, so the same helpers reproduce ALM and PAU keys.
    /// Numeric arguments are declared narrower than uint256 on chain (uint16 Centrifuge
    /// ids, uint32 CCTP domains and LayerZero endpoint ids) but abi.encode pads them all
    /// to a word, so one uint256 overload reproduces every numeric shape.
    function _limitKey(string memory name) internal pure returns (bytes32) {
        return keccak256(bytes(name));
    }

    function _limitKey(string memory name, address a) internal pure returns (bytes32) {
        return keccak256(abi.encode(_limitKey(name), a));
    }

    function _limitKey(string memory name, address a, address b) internal pure returns (bytes32) {
        return keccak256(abi.encode(_limitKey(name), a, b));
    }

    function _limitKey(string memory name, address a, uint256 n) internal pure returns (bytes32) {
        return keccak256(abi.encode(_limitKey(name), a, n));
    }

    function _limitKey(string memory name, uint256 n) internal pure returns (bytes32) {
        return keccak256(abi.encode(_limitKey(name), n));
    }

    /// @dev Asserts the registry and the live set are the same set, in both directions.
    /// A live key missing from the registry means an onboarding went unregistered. A
    /// registered key that is not live means the registry kept an entry an offboarding
    /// removed, which also catches a truncated log fetch silently shrinking the live set.
    function _checkRateLimitCoverage(
        RateLimitIntegration[] memory integrations,
        bytes32[]             memory discovered
    ) internal {
        uint256 notLive;

        for (uint256 i; i < integrations.length; ++i) {
            bytes32[4] memory keys = [
                integrations[i].entryId,
                integrations[i].entryId2,
                integrations[i].exitId,
                integrations[i].exitId2
            ];

            require(
                keys[0] != bytes32(0) || keys[1] != bytes32(0) ||
                keys[2] != bytes32(0) || keys[3] != bytes32(0),
                string(abi.encodePacked(
                    "CommonRateLimitTests/integration-has-no-keys ", integrations[i].label
                ))
            );

            for (uint256 j; j < keys.length; ++j) {
                if (keys[j] == bytes32(0)) continue;

                if (!_containsKey(discovered, keys[j])) {
                    console.log("Registered rate limit is not live:", integrations[i].label);
                    ++notLive;
                    continue;
                }

                discovered = _removeKey(discovered, keys[j]);
            }
        }

        for (uint256 i; i < discovered.length; ++i) {
            console.log("Unregistered rate limit key:", vm.toString(discovered[i]));
        }

        assertEq(discovered.length, 0, "CommonRateLimitTests/rate-limit-keys-not-covered");
        assertEq(notLive,           0, "CommonRateLimitTests/registered-rate-limits-not-live");
    }

    /// @dev Rejects limits that are implausible in either direction, which catches a
    /// misplaced decimal in a spell. Unlimited and zero-slope limits are deliberate
    /// configurations rather than mistakes, so they are exempt.
    function _checkRateLimitValue(address rateLimits, bytes32 key, address asset)
        private view returns (string memory problem)
    {
        if (key == bytes32(0)) return "";

        IRateLimits.RateLimitData memory data = IRateLimits(rateLimits).getRateLimitData(key);

        if (data.maxAmount == type(uint256).max)                    return "";
        if (data.slope     == 0 || data.slope == type(uint256).max) return "";

        uint256 unit = 10 ** _assetDecimals(asset);

        if (data.maxAmount      / unit > 1e10) return "max-amount-over-10b";
        if (data.slope * 1 days / unit > 1e10) return "slope-over-10b-per-day";
        if (data.maxAmount      / unit == 0)   return "max-amount-under-one-unit";
        if (data.slope * 1 days / unit == 0)   return "slope-under-one-unit-per-day";

        return "";
    }

    function _checkRateLimitValues(address rateLimits, RateLimitIntegration memory integration) private view {
        _requireSaneValue(rateLimits, integration, integration.entryId);
        _requireSaneValue(rateLimits, integration, integration.entryId2);
        _requireSaneValue(rateLimits, integration, integration.exitId);
        _requireSaneValue(rateLimits, integration, integration.exitId2);
    }

    function _requireSaneValue(
        address                     rateLimits,
        RateLimitIntegration memory integration,
        bytes32                     key
    ) private view {
        string memory problem = _checkRateLimitValue(rateLimits, key, integration.asset);

        require(
            bytes(problem).length == 0,
            string(abi.encodePacked("CommonRateLimitTests/", problem, " ", integration.label))
        );
    }

    /// @dev Limits denominated in something other than a single token record a zero asset
    /// and fall back to 18, which is the convention the controllers use for those.
    function _assetDecimals(address asset) private view returns (uint8) {
        if (asset == address(0)) return 18;

        try IERC20(asset).decimals() returns (uint8 assetDecimals) {
            return assetDecimals;
        } catch {
            revert(string(abi.encodePacked(
                "CommonRateLimitTests/asset-has-no-decimals ", vm.toString(asset)
            )));
        }
    }

    function _appendKey(bytes32[] memory keys, bytes32 key) private pure returns (bytes32[] memory) {
        for (uint256 i; i < keys.length; ++i) {
            if (keys[i] == key) return keys;
        }

        bytes32[] memory extended = new bytes32[](keys.length + 1);

        for (uint256 i; i < keys.length; ++i) {
            extended[i] = keys[i];
        }

        extended[keys.length] = key;

        return extended;
    }

    function _containsKey(bytes32[] memory keys, bytes32 key) private pure returns (bool) {
        for (uint256 i; i < keys.length; ++i) {
            if (keys[i] == key) return true;
        }

        return false;
    }

    function _removeKey(bytes32[] memory keys, bytes32 key) private pure returns (bytes32[] memory) {
        for (uint256 i; i < keys.length; ++i) {
            if (keys[i] != key) continue;

            bytes32[] memory shortened = new bytes32[](keys.length - 1);

            for (uint256 j; j < keys.length; ++j) {
                if (j < i)      shortened[j]     = keys[j];
                else if (j > i) shortened[j - 1] = keys[j];
            }

            return shortened;
        }

        return keys;
    }

    function _concat(VmSafe.EthGetLogs[] memory left, VmSafe.EthGetLogs[] memory right)
        private pure returns (VmSafe.EthGetLogs[] memory joined)
    {
        joined = new VmSafe.EthGetLogs[](left.length + right.length);

        for (uint256 i; i < left.length; ++i) {
            joined[i] = left[i];
        }

        for (uint256 i; i < right.length; ++i) {
            joined[left.length + i] = right[i];
        }
    }

}
