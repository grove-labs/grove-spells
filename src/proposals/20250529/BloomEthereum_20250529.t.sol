// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/BloomTestBase.sol";

import { CentrifugeConfig } from "../../test-harness/BloomLiquidityLayerTests.sol";

contract BloomEthereum_20250529Test is BloomTestBase {

    address internal constant CENTRIFUGE_JTRSY_VAULT = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;

    constructor() {
        id = "20250529";
    }

    function setUp() public {
        // May 2, 2025
        setupDomain({ mainnetForkBlock: 22396975 });
        deployPayload();
    }

    function test_centrifugeVaultOnboarding() public {
        _testCentrifugeOnboarding(
            CENTRIFUGE_JTRSY_VAULT,
            100_000_000e6,
            100_000_000e6,
            50_000_000e6 / uint256(1 days)
        );
    }

}
