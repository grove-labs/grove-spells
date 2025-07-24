// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ChainIdUtils } from "../../libraries/ChainId.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250807Test is GroveTestBase {

    constructor() {
        id = "20250807";
    }

    function setUp() public {
        setupDomains("2025-07-23T15:15:00Z");
        deployPayloads();

        chainData[ChainIdUtils.Avalanche()].payload = 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a;
    }

    function test_ETHEREUM_upgradeController() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_migrateCentrifugeJtrsy() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_migrateCentrifugeJaaa() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardCentrifugeCrosschainTransfers() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardStakedUSDCVault() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardSparkLend() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardEthena() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_AVALANCHE_initializeLiquidityLayer() public onChain(ChainIdUtils.Avalanche()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_AVALANCHE_onboardCentrifugeJtrsy() public onChain(ChainIdUtils.Avalanche()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_AVALANCHE_onboardCentrifugeJaaa() public onChain(ChainIdUtils.Avalanche()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_AVALANCHE_onboardCentrifugeCrosschainTransfers() public onChain(ChainIdUtils.Avalanche()) {
        vm.skip(true);
        // TODO: Implement
    }

}
