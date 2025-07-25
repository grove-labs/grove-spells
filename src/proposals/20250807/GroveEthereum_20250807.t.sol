// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IALMProxy }         from "grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";

import { ChainIdUtils } from "src/libraries/ChainId.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250807Test is GroveTestBase {

    address internal constant NEW_MAINNET_CONTROLLER = 0x28170D5084cc3cEbFC5f21f30DB076342716f30C;
    address internal constant DEPLOYER               = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;
    address internal constant FAKE_PSM3_PLACEHOLDER  = 0x00000000000000000000000000000000DeaDBeef;

    constructor() {
        id = "20250807";
    }

    function setUp() public {
        setupDomains("2025-07-25T00:00:00Z");
        deployPayloads();

        chainData[ChainIdUtils.Avalanche()].payload = 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a;
    }

    function test_ETHEREUM_upgradeController() public onChain(ChainIdUtils.Ethereum()) {
        _testControllerUpgrade({
            oldController: Ethereum.ALM_CONTROLLER,
            newController: NEW_MAINNET_CONTROLLER
        });
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

    function test_AVALANCHE_almSystemDeployment() public onChain(ChainIdUtils.Avalanche()) {
        IALMProxy         almProxy   = IALMProxy(Avalanche.ALM_PROXY);
        IRateLimits       rateLimits = IRateLimits(Avalanche.ALM_RATE_LIMITS);
        ForeignController controller = ForeignController(Avalanche.ALM_CONTROLLER);

        assertEq(almProxy.hasRole(0x0, Avalanche.GROVE_EXECUTOR),   true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Avalanche.GROVE_EXECUTOR), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Avalanche.GROVE_EXECUTOR), true, "incorrect-admin-controller");

        assertEq(almProxy.hasRole(0x0, DEPLOYER),   false, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, DEPLOYER), false, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, DEPLOYER), false, "incorrect-admin-controller");

        assertEq(address(controller.proxy()),      Avalanche.ALM_PROXY,            "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), Avalanche.ALM_RATE_LIMITS,      "incorrect-rateLimits");
        assertEq(address(controller.cctp()),       Avalanche.CCTP_TOKEN_MESSENGER, "incorrect-cctpMessenger");
        assertEq(address(controller.usdc()),       Avalanche.USDC,                 "incorrect-usdc");
        assertEq(address(controller.psm()),        FAKE_PSM3_PLACEHOLDER,          "incorrect-psm");
    }

    function test_AVALANCHE_almSystemInitialization() public onChain(ChainIdUtils.Avalanche()) {
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
