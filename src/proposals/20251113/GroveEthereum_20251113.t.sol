// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20251030_Test is GroveTestBase {

    constructor() {
        id = "20251113";
    }

    function setUp() public {
        setupDomains("2025-10-30T12:00:00Z");

        deployPayloads();
    }

}
