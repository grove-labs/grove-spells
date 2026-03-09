// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260326_Test is GroveTestBase {

    address internal constant CENTRIFUGE_ACRDX      = 0x74A739EA1Dc67c5a0179ebad665D1D3c4b80B712;
    address internal constant SENTORA_PYUSD_MAIN_V2 = 0xb576765fB15505433aF24FEe2c0325895C559FB2;

    constructor() {
        id = "20260326";
    }

    function setUp() public {
        setupDomains("2026-01-24T12:00:00Z");

        deployPayloads();
    }

    function test_ETHEREUM_onboardCentrifugeAcrdx() public onChain(ChainIdUtils.Ethereum()) {
        _testCentrifugeV3Onboarding({
            centrifugeVault : CENTRIFUGE_ACRDX,
            depositMax      : 20_000_000e6,
            depositSlope    : 20_000_000e6 / uint256(1 days)
        });
    }

    function test_ETHEREUM_onboardSentoraPyusdMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : SENTORA_PYUSD_MAIN_V2,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : 50_000_000e6,
            depositSlope          : 50_000_000e6 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 3e6
        });
    }

}
