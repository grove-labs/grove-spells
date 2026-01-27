// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260212_Test is GroveTestBase {

    address internal constant GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT = 0xBEEfF0d672ab7F5018dFB614c93981045D4aA98a;

    uint256 internal constant GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_TEST_DEPOSIT         = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_DEPOSIT_MAX          = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_DEPOSIT_SLOPE        = 20_000_000e6 / uint256(1 days);
    uint256 internal constant GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_SHARE_UNIT           = 1e18;
    uint256 internal constant GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_MAX_ASSETS_PER_SHARE = 2e6;

    constructor() {
        id = "20260212";
    }

    function setUp() public {
        setupDomains("2026-01-27T12:00:00Z");

        deployPayloads();
    }

    function test_ETHEREUM_onboardGroveXSteakhouseAusdMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT,
            expectedDepositAmount : GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_DEPOSIT_SLOPE,
            shareUnit             : GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_SHARE_UNIT,
            maxAssetsPerShare     : GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT_MAX_ASSETS_PER_SHARE
        });
    }

}
