// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IALMProxy }   from "grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";
import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/GroveLiquidityLayerTests.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250807Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant FAKE_PSM3_PLACEHOLDER = 0x00000000000000000000000000000000DeaDBeef;

    address internal constant NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;
    address internal constant NEW_MAINNET_CENTRIFUGE_JAAA_VAULT  = 0x4880799eE5200fC58DA299e965df644fBf46780B;

    address internal constant NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;
    address internal constant NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT  = 0x1121F4e21eD8B9BC1BB9A2952cDD8639aC897784;

    uint256 internal constant ZERO = 0;

    uint256 internal constant OLD_MAINNET_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant OLD_MAINNET_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant OLD_MAINNET_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant OLD_MAINNET_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_MAINNET_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant NEW_MAINNET_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_MAINNET_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant NEW_MAINNET_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_AVALANCHE_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant NEW_AVALANCHE_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_AVALANCHE_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant NEW_AVALANCHE_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    constructor() {
        id = "20250807";
    }

    function setUp() public {
        setupDomains("2025-07-25T18:15:00Z");
        deployPayloads();

        chainData[ChainIdUtils.Avalanche()].payload = 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a;
    }

    function test_ETHEREUM_offboardOldCentrifugeJtrsy() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Unskip after the old JTRSY is onboarded
        vm.skip(true);

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        bytes32 oldJtrsyDepositKey = RateLimitHelpers.makeAssetKey({
            key   : MainnetController(ctx.controller).LIMIT_7540_DEPOSIT(),
            asset : Ethereum.CENTRIFUGE_JTRSY
        });

        _assertRateLimit({
            key       : oldJtrsyDepositKey,
            maxAmount : OLD_MAINNET_JTRSY_RATE_LIMIT_MAX,
            slope     : OLD_MAINNET_JTRSY_RATE_LIMIT_SLOPE
        });

        executeAllPayloadsAndBridges();

        _assertRateLimit({
            key       : oldJtrsyDepositKey,
            maxAmount : ZERO,
            slope     : ZERO
        });
    }

    function test_ETHEREUM_onboardNewCentrifugeJtrsy() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Unskip after proxy is onboarded to the new JTRSY vault
        vm.skip(true);

        _testCentrifugeV3Onboarding({
            centrifugeVault        : NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT,
            expectedDepositAmount  : 50_000_000e6,
            depositMax             : NEW_MAINNET_JTRSY_RATE_LIMIT_MAX,
            depositSlope           : NEW_MAINNET_JTRSY_RATE_LIMIT_SLOPE
        });
    }

    function test_ETHEREUM_offboardOldCentrifugeJaaa() public onChain(ChainIdUtils.Ethereum()) {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        bytes32 oldJaaaDepositKey = RateLimitHelpers.makeAssetKey({
            key   : MainnetController(ctx.controller).LIMIT_7540_DEPOSIT(),
            asset : Ethereum.CENTRIFUGE_JAAA
        });

        _assertRateLimit({
            key       : oldJaaaDepositKey,
            maxAmount : OLD_MAINNET_JAAA_RATE_LIMIT_MAX,
            slope     : OLD_MAINNET_JAAA_RATE_LIMIT_SLOPE
        });

        executeAllPayloadsAndBridges();

        _assertRateLimit({
            key       : oldJaaaDepositKey,
            maxAmount : ZERO,
            slope     : ZERO
        });
    }

    function test_ETHEREUM_onboardNewCentrifugeJaaa() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Unskip after proxy is onboarded to the new JAAA vault
        vm.skip(true);

        _testCentrifugeV3Onboarding({
            centrifugeVault        : NEW_MAINNET_CENTRIFUGE_JAAA_VAULT,
            expectedDepositAmount  : 50_000_000e6,
            depositMax             : NEW_MAINNET_JAAA_RATE_LIMIT_MAX,
            depositSlope           : NEW_MAINNET_JAAA_RATE_LIMIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardEthena() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Add actual tests !!!!!!!!

        executeAllPayloadsAndBridges();

        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        IERC20 usdc    = IERC20(Ethereum.USDC);
        IERC20 usde    = IERC20(Ethereum.USDE);
        IERC4626 susde = IERC4626(Ethereum.SUSDE);

        // Use realistic numbers to check the rate limits
        uint256 usdcAmount = 5_000_000e6;
        uint256 usdeAmount = usdcAmount * 1e12;

        // Use deal2 for USDC because storage is not set in a common way
        deal2(Ethereum.USDC, Ethereum.ALM_PROXY, usdcAmount);

        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 0);
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
        IALMProxy         almProxy   = IALMProxy(Avalanche.ALM_PROXY);
        IRateLimits       rateLimits = IRateLimits(Avalanche.ALM_RATE_LIMITS);
        ForeignController controller = ForeignController(Avalanche.ALM_CONTROLLER);

        executeAllPayloadsAndBridges();

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), Avalanche.ALM_CONTROLLER), true, "incorrect-controller-almProxy");

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Avalanche.ALM_CONTROLLER), true, "incorrect-controller-rateLimits");

        assertEq(controller.hasRole(controller.FREEZER(), Avalanche.ALM_FREEZER), true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), Avalanche.ALM_RELAYER), true, "incorrect-relayer-controller");

        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),  bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    }

    function test_AVALANCHE_onboardCctpTransfersToEthereum() public onChain(ChainIdUtils.Avalanche()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_AVALANCHE_onboardCentrifugeJtrsy() public onChain(ChainIdUtils.Avalanche()) {
        // TODO: Unskip after proxy is onboarded to the new JTRSY vault
        vm.skip(true);

        _testCentrifugeV3Onboarding({
            centrifugeVault        : NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT,
            expectedDepositAmount  : 50_000_000e6,
            depositMax             : NEW_AVALANCHE_JTRSY_RATE_LIMIT_MAX,
            depositSlope           : NEW_AVALANCHE_JTRSY_RATE_LIMIT_SLOPE
        });
    }

    function test_AVALANCHE_onboardCentrifugeJaaa() public onChain(ChainIdUtils.Avalanche()) {
        // TODO: Unskip after proxy is onboarded to the new JAAA vault
        vm.skip(true);

        _testCentrifugeV3Onboarding({
            centrifugeVault        : NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT,
            expectedDepositAmount  : 50_000_000e6,
            depositMax             : NEW_AVALANCHE_JAAA_RATE_LIMIT_MAX,
            depositSlope           : NEW_AVALANCHE_JAAA_RATE_LIMIT_SLOPE
        });
    }

}
