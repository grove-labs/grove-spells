// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test }   from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { RateLimitTestHelpers } from "./CommonRateLimitTests.sol";

contract RateLimitTestHelpersTest is Test {

    function test_replayHandlesLifecycle() public pure {
        bytes32 keyA = keccak256("A");
        bytes32 keyB = keccak256("B");

        VmSafe.EthGetLogs[] memory logs = new VmSafe.EthGetLogs[](5);
        logs[0] = _rateLimitLog(keyA, 100);
        logs[1] = _rateLimitLog(keyA, 200);
        logs[2] = _rateLimitLog(keyB, 300);
        logs[3] = _rateLimitLog(keyA, 0);
        logs[4] = _rateLimitLog(keyA, 400);

        bytes32[] memory keys = RateLimitTestHelpers.replay(logs);

        assertEq(keys.length, 2);
        assertEq(keys[0], keyB);
        assertEq(keys[1], keyA);
    }

    function test_zeroSlopeStillValidatesFiniteMax() public pure {
        assertEq(
            RateLimitTestHelpers.checkValue(10_000_000_001e18, 0, 1e18),
            "max-amount-over-10b"
        );
    }

    function _rateLimitLog(bytes32 key, uint256 maxAmount)
        private pure returns (VmSafe.EthGetLogs memory log)
    {
        log.topics = new bytes32[](2);
        log.topics[1] = key;
        log.data = abi.encode(maxAmount, uint256(0), maxAmount, uint256(0));
    }

}
