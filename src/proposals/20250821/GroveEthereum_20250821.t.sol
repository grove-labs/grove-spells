// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250821Test is GroveTestBase {

    constructor() {
        id = "20250821";
    }

    function setUp() public {
        setupDomains("2025-07-31T16:50:00Z");
        deployPayloads();
    }

}
