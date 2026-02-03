// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260212_Test is GroveTestBase {

    address internal constant ETHEREUM_PAYLOAD = 0xe045AA2065FDba35a0e0B5283e7f36a8ca96886a;

    address internal constant GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT = 0xBEEfF0d672ab7F5018dFB614c93981045D4aA98a;

    constructor() {
        id = "20260212";
    }

    function setUp() public {
        setupDomains("2026-02-03T12:00:00Z");

        chainData[ChainIdUtils.Ethereum()].payload = ETHEREUM_PAYLOAD;
    }

    function test_ETHEREUM_onboardGroveXSteakhouseAusdMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT,
            expectedDepositAmount : 20_000_000e6,
            depositMax            : 20_000_000e6,
            depositSlope          : 20_000_000e6 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 2e6
        });
    }

}
