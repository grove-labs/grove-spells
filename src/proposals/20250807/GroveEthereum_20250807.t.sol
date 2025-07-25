// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ChainIdUtils } from "../../libraries/ChainId.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250807Test is GroveTestBase {

    address internal constant NEW_ALM_CONTROLLER = 0x28170D5084cc3cEbFC5f21f30DB076342716f30C;

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

    function test_ETHEREUM_onboardSteakUSDCVault() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardSparkLend() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardEthena() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        MainnetController controller = MainnetController(NEW_ALM_CONTROLLER);

        IERC20 usdc    = IERC20(Ethereum.USDC);
        IERC20 usde    = IERC20(Ethereum.USDE);
        IERC4626 susde = IERC4626(Ethereum.SUSDE);
        
        // Use realistic numbers to check the rate limits
        uint256 usdcAmount = 5_000_000e6;
        uint256 usdeAmount = usdcAmount * 1e12;

        // Use deal2 for USDC because storage is not set in a common way
        deal2(Ethereum.uSDC, Ethereum.ALM_PROXY, usdcAmount);

        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 0);
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
