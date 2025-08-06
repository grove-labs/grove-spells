// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers } from "grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/GroveLiquidityLayerTests.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250821Test is GroveTestBase {

    // TODO Set payload addresses after deployment
    // address internal constant ETHEREUM_PAYLOAD  = 0x0000000000000000000000000000000000000000;
    // address internal constant AVALANCHE_PAYLOAD = 0x0000000000000000000000000000000000000000;

    address internal constant PREVIOUS_ETHEREUM_PAYLOAD  = 0xa25127f759B6F07020bf2206D31bEb6Ed04D1550;
    address internal constant PREVIOUS_AVALANCHE_PAYLOAD = 0x6AC0865E7fcAd8B89850b83A709eEC57569f919f;

    address internal constant NEW_MAINNET_CONTROLLER   = 0x28170D5084cc3cEbFC5f21f30DB076342716f30C; // TODO Change to a proper address
    address internal constant NEW_AVALANCHE_CONTROLLER = 0xbA41d5F95DF891862bf28bEA261AEc0efd6D0FAA; // TODO Change to a proper address

    address internal constant NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A; // TODO Confirm the address
    address internal constant NEW_MAINNET_CENTRIFUGE_JAAA_VAULT  = 0x4880799eE5200fC58DA299e965df644fBf46780B; // TODO Confirm the address

    address internal constant NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT  = 0x1121F4e21eD8B9BC1BB9A2952cDD8639aC897784; // TODO Confirm the address
    address internal constant NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A; // TODO Confirm the address

    uint256 internal constant ZERO = 0;

    uint256 internal constant OLD_MAINNET_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant OLD_MAINNET_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant OLD_MAINNET_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant OLD_MAINNET_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_MAINNET_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;                   // TODO Set proper value
    uint256 internal constant NEW_MAINNET_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant NEW_MAINNET_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant NEW_MAINNET_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant NEW_AVALANCHE_JAAA_RATE_LIMIT_MAX    = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant NEW_AVALANCHE_JAAA_RATE_LIMIT_SLOPE  = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant NEW_AVALANCHE_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;                   // TODO Set proper value
    uint256 internal constant NEW_AVALANCHE_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant MAINNET_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant MAINNET_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant AVALANCHE_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant AVALANCHE_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant AVALANCHE_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant AVALANCHE_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID  = 1;
    uint16 internal constant AVALANCHE_DESTINATION_CENTRIFUGE_ID = 5;

    constructor() {
        id = "20250821";
    }

    function setUp() public {
        setupDomains("2025-07-31T16:50:00Z");

        // TODO: Remove this once the Aug 7th spell is executed
        _executePreviousPayloads();

        // TODO Remove dynamic payload deployment and set addresses statically after payloads are deployed
        deployPayloads();
        // chainData[ChainIdUtils.Ethereum()].payload  = ETHEREUM_PAYLOAD;
        // chainData[ChainIdUtils.Avalanche()].payload = AVALANCHE_PAYLOAD;

        // Prepare testing setup for the controller upgrade
        chainData[ChainIdUtils.Ethereum()].newController  = NEW_MAINNET_CONTROLLER;
        chainData[ChainIdUtils.Avalanche()].newController = NEW_AVALANCHE_CONTROLLER;
    }

    function _executePreviousPayloads() internal {
        // Execute previous payloads to set up the state
        chainData[ChainIdUtils.Ethereum()].payload  = PREVIOUS_ETHEREUM_PAYLOAD;
        chainData[ChainIdUtils.Avalanche()].payload = PREVIOUS_AVALANCHE_PAYLOAD;
        executeAllPayloadsAndBridges();
    }

    function test_ETHEREUM_upgradeController() public onChain(ChainIdUtils.Ethereum()) {
        _testControllerUpgrade({
            oldController : Ethereum.ALM_CONTROLLER,
            newController : NEW_MAINNET_CONTROLLER
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

    function test_ETHEREUM_offboardOldCentrifugeJtrsy() public onChain(ChainIdUtils.Ethereum()) {
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

    function test_ETHEREUM_onboardNewCentrifugeJaaa() public onChain(ChainIdUtils.Ethereum()) {
        _testCentrifugeV3Onboarding({
            centrifugeVault       : NEW_MAINNET_CENTRIFUGE_JAAA_VAULT,
            usdcAddress           : Ethereum.USDC,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : NEW_MAINNET_JAAA_RATE_LIMIT_MAX,
            depositSlope          : NEW_MAINNET_JAAA_RATE_LIMIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardNewCentrifugeJtrsy() public onChain(ChainIdUtils.Ethereum()) {
        _testCentrifugeV3Onboarding({
            centrifugeVault       : NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT,
            usdcAddress           : Ethereum.USDC,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : NEW_MAINNET_JTRSY_RATE_LIMIT_MAX,
            depositSlope          : NEW_MAINNET_JTRSY_RATE_LIMIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardCentrifugeJaaaCrosschainTransfer() public onChain(ChainIdUtils.Ethereum()) {
       _testCentrifugeCrosschainTransferOnboarding({
        centrifugeVault         : NEW_MAINNET_CENTRIFUGE_JAAA_VAULT,
        destinationCentrifugeId : AVALANCHE_DESTINATION_CENTRIFUGE_ID,
        maxAmount               : MAINNET_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
        slope                   : MAINNET_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
       });
    }

    function test_ETHEREUM_onboardCentrifugeJtrsyCrosschainTransfer() public onChain(ChainIdUtils.Ethereum()) {
       _testCentrifugeCrosschainTransferOnboarding({
        centrifugeVault         : NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT,
        destinationCentrifugeId : AVALANCHE_DESTINATION_CENTRIFUGE_ID,
        maxAmount               : MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
        slope                   : MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
       });
    }

    function test_AVALANCHE_upgradeController() public onChain(ChainIdUtils.Avalanche()) {
        _testControllerUpgrade({
            oldController : Avalanche.ALM_CONTROLLER,
            newController : NEW_AVALANCHE_CONTROLLER
        });
    }

    function test_AVALANCHE_onboardCentrifugeJaaa() public onChain(ChainIdUtils.Avalanche()) {
        _testCentrifugeV3Onboarding({
            centrifugeVault       : NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT,
            usdcAddress           : Avalanche.USDC,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : NEW_AVALANCHE_JAAA_RATE_LIMIT_MAX,
            depositSlope          : NEW_AVALANCHE_JAAA_RATE_LIMIT_SLOPE
        });
    }

    function test_AVALANCHE_onboardCentrifugeJtrsy() public onChain(ChainIdUtils.Avalanche()) {
        _testCentrifugeV3Onboarding({
            centrifugeVault       : NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT,
            usdcAddress           : Avalanche.USDC,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : NEW_AVALANCHE_JTRSY_RATE_LIMIT_MAX,
            depositSlope          : NEW_AVALANCHE_JTRSY_RATE_LIMIT_SLOPE
        });
    }

    function test_AVALANCHE_onboardCentrifugeJaaaCrosschainTransfer() public onChain(ChainIdUtils.Avalanche()) {
       _testCentrifugeCrosschainTransferOnboarding({
        centrifugeVault         : NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT,
        destinationCentrifugeId : ETHEREUM_DESTINATION_CENTRIFUGE_ID,
        maxAmount               : AVALANCHE_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
        slope                   : AVALANCHE_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
       });
    }

    function test_AVALANCHE_onboardCentrifugeJtrsyCrosschainTransfer() public onChain(ChainIdUtils.Avalanche()) {
       _testCentrifugeCrosschainTransferOnboarding({
        centrifugeVault         : NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT,
        destinationCentrifugeId : ETHEREUM_DESTINATION_CENTRIFUGE_ID,
        maxAmount               : AVALANCHE_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
        slope                   : AVALANCHE_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
       });
    }

}
