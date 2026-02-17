// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260226_Test is GroveTestBase {

    address internal constant PAYLOAD_ETHEREUM = 0xa2BDc0375Fc1C1343f7F6bf6c34c0263df1F0DB8;
    address internal constant PAYLOAD_BASE     = 0xfC3e2Fa0257d4454fFD6a079dd38f132b361AB9a;

    address internal constant GALAXY_DEPOSIT_WALLET        = 0x3E23311f9FF660E3c3d87E4b7c207b3c3D7e04f0;
    address internal constant STEAKHOUSE_MORPHO_USDC_VAULT = 0xbeef0e0834849aCC03f0089F01f4F1Eeb06873C9;

    constructor() {
        id = "20260226";
    }

    function setUp() public {
        setupDomains("2026-02-17T10:48:00Z");

        chainData[ChainIdUtils.Ethereum()].payload = PAYLOAD_ETHEREUM;
        chainData[ChainIdUtils.Base()].payload     = PAYLOAD_BASE;
    }

    function test_ETHEREUM_onboardGalaxyDeposits() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : GALAXY_DEPOSIT_WALLET,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : 50_000_000e6,
            depositSlope          : 50_000_000e6 / uint256(1 days)
        });
    }

    function test_BASE_onboardSteakhouseMorphoUsdcVault() public onChain(ChainIdUtils.Base()) {
        _testERC4626Onboarding({
            vault                 : STEAKHOUSE_MORPHO_USDC_VAULT,
            expectedDepositAmount : 20_000_000e6,
            depositMax            : 20_000_000e6,
            depositSlope          : 20_000_000e6 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 2e6
        });
    }

}
