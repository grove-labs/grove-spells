// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/GroveLiquidityLayerTests.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250821Test is GroveTestBase {

    address internal constant ETHEREUM_PAYLOAD  = 0xFa533FEd0F065dEf8dcFA6699Aa3d73337302BED;
    address internal constant AVALANCHE_PAYLOAD = 0xde73D4AB2b728b3826AA18aC7ACDE71677A3Ae4a;

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant FAKE_PSM3_PLACEHOLDER = 0x00000000000000000000000000000000DeaDBeef;

    address internal constant NEW_MAINNET_CONTROLLER   = 0xB111E07c8B939b0Fe701710b365305F7F23B0edd;
    address internal constant NEW_AVALANCHE_CONTROLLER = 0x734266cE1E49b148eF633f2E0358382488064999;

    address internal constant NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;
    address internal constant NEW_MAINNET_CENTRIFUGE_JAAA_VAULT  = 0x4880799eE5200fC58DA299e965df644fBf46780B;

    address internal constant NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT  = 0x1121F4e21eD8B9BC1BB9A2952cDD8639aC897784;
    address internal constant NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;

    uint256 internal constant OLD_MAINNET_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant OLD_MAINNET_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant OLD_MAINNET_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant OLD_MAINNET_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_MAINNET_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant NEW_MAINNET_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_MAINNET_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant NEW_MAINNET_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_AVALANCHE_JAAA_RATE_LIMIT_MAX    = 50_000_000e6;
    uint256 internal constant NEW_AVALANCHE_JAAA_RATE_LIMIT_SLOPE  = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_AVALANCHE_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant NEW_AVALANCHE_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant MAINNET_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant MAINNET_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant AVALANCHE_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant AVALANCHE_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant AVALANCHE_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant AVALANCHE_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID  = 1;
    uint16 internal constant AVALANCHE_DESTINATION_CENTRIFUGE_ID = 5;

    constructor() {
        id = "20250821";
    }

    function setUp() public {
        setupDomains("2025-08-15T17:50:00Z");

        chainData[ChainIdUtils.Ethereum()].payload  = ETHEREUM_PAYLOAD;
        chainData[ChainIdUtils.Avalanche()].payload = AVALANCHE_PAYLOAD;

        // Prepare testing setup for the controller upgrade
        chainData[ChainIdUtils.Ethereum()].newController  = NEW_MAINNET_CONTROLLER;
        chainData[ChainIdUtils.Avalanche()].newController = NEW_AVALANCHE_CONTROLLER;
    }

    function test_ETHEREUM_upgradeController() public onChain(ChainIdUtils.Ethereum()) {
        _verifyMainnetControllerDeployment(
            AlmSystemContracts({
                admin      : Ethereum.GROVE_PROXY,
                proxy      : Ethereum.ALM_PROXY,
                rateLimits : Ethereum.ALM_RATE_LIMITS,
                controller : NEW_MAINNET_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
                freezer  : Ethereum.ALM_FREEZER,
                relayer  : Ethereum.ALM_RELAYER
            }),
            MainnetAlmSystemDependencies({
                vault   : Ethereum.ALLOCATOR_VAULT,
                psm     : Ethereum.PSM,
                daiUsds : Ethereum.DAI_USDS,
                cctp    : Ethereum.CCTP_TOKEN_MESSENGER
            })
        );
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

        bytes32 oldJaaaRedeemKey = RateLimitHelpers.makeAssetKey({
            key   : MainnetController(ctx.controller).LIMIT_7540_REDEEM(),
            asset : Ethereum.CENTRIFUGE_JAAA
        });

        _assertRateLimit({
            key       : oldJaaaDepositKey,
            maxAmount : OLD_MAINNET_JAAA_RATE_LIMIT_MAX,
            slope     : OLD_MAINNET_JAAA_RATE_LIMIT_SLOPE
        });

        _assertUnlimitedRateLimit(oldJaaaRedeemKey);

        executeAllPayloadsAndBridges();

        _assertZeroRateLimit(oldJaaaDepositKey);
        _assertZeroRateLimit(oldJaaaRedeemKey);
    }

    function test_ETHEREUM_offboardOldCentrifugeJtrsy() public onChain(ChainIdUtils.Ethereum()) {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        bytes32 oldJtrsyDepositKey = RateLimitHelpers.makeAssetKey({
            key   : MainnetController(ctx.controller).LIMIT_7540_DEPOSIT(),
            asset : Ethereum.CENTRIFUGE_JTRSY
        });

        bytes32 oldJtrsyRedeemKey = RateLimitHelpers.makeAssetKey({
            key   : MainnetController(ctx.controller).LIMIT_7540_REDEEM(),
            asset : Ethereum.CENTRIFUGE_JTRSY
        });

        _assertRateLimit({
            key       : oldJtrsyDepositKey,
            maxAmount : OLD_MAINNET_JTRSY_RATE_LIMIT_MAX,
            slope     : OLD_MAINNET_JTRSY_RATE_LIMIT_SLOPE
        });

        _assertUnlimitedRateLimit(oldJtrsyRedeemKey);

        executeAllPayloadsAndBridges();

        _assertZeroRateLimit(oldJtrsyDepositKey);
        _assertZeroRateLimit(oldJtrsyRedeemKey);
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

    function test_ETHEREUM_setCentrifugeCrosschainTransferRecipient() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 centrifugeRecipientBefore = MainnetController(NEW_MAINNET_CONTROLLER).centrifugeRecipients(AVALANCHE_DESTINATION_CENTRIFUGE_ID);

        assertEq(centrifugeRecipientBefore, bytes32(0));

        executeAllPayloadsAndBridges();

        bytes32 centrifugeRecipientAfter = MainnetController(NEW_MAINNET_CONTROLLER).centrifugeRecipients(AVALANCHE_DESTINATION_CENTRIFUGE_ID);

        assertEq(centrifugeRecipientAfter, bytes32(uint256(uint160(Avalanche.ALM_PROXY))));
    }

    function test_ETHEREUM_onboardCentrifugeJaaaCrosschainTransfer() public onChain(ChainIdUtils.Ethereum()) {
       _testCentrifugeCrosschainTransferOnboarding({
        centrifugeVault         : NEW_MAINNET_CENTRIFUGE_JAAA_VAULT,
        destinationAddress      : Avalanche.ALM_PROXY,
        destinationCentrifugeId : AVALANCHE_DESTINATION_CENTRIFUGE_ID,
        expectedTransferAmount  : 10_000_000e6,
        maxAmount               : MAINNET_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
        slope                   : MAINNET_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
       });
    }

    function test_ETHEREUM_onboardCentrifugeJtrsyCrosschainTransfer() public onChain(ChainIdUtils.Ethereum()) {
       _testCentrifugeCrosschainTransferOnboarding({
        centrifugeVault         : NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT,
        destinationAddress      : Avalanche.ALM_PROXY,
        destinationCentrifugeId : AVALANCHE_DESTINATION_CENTRIFUGE_ID,
        expectedTransferAmount  : 10_000_000e6,
        maxAmount               : MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
        slope                   : MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
       });
    }

    function test_AVALANCHE_upgradeController() public onChain(ChainIdUtils.Avalanche()) {
        _verifyForeignControllerDeployment(
            AlmSystemContracts({
                admin      : Avalanche.GROVE_EXECUTOR,
                proxy      : Avalanche.ALM_PROXY,
                rateLimits : Avalanche.ALM_RATE_LIMITS,
                controller : NEW_AVALANCHE_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
                freezer  : Avalanche.ALM_FREEZER,
                relayer  : Avalanche.ALM_RELAYER
            }),
            ForeignAlmSystemDependencies({
                psm  : FAKE_PSM3_PLACEHOLDER,
                usdc : Avalanche.USDC,
                cctp : Avalanche.CCTP_TOKEN_MESSENGER
            })
        );
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

    function test_AVALANCHE_setCentrifugeCrosschainTransferRecipient() public onChain(ChainIdUtils.Avalanche()) {
        bytes32 centrifugeRecipientBefore = ForeignController(NEW_AVALANCHE_CONTROLLER).centrifugeRecipients(ETHEREUM_DESTINATION_CENTRIFUGE_ID);

        assertEq(centrifugeRecipientBefore, bytes32(0));

        executeAllPayloadsAndBridges();

        bytes32 centrifugeRecipientAfter = ForeignController(NEW_AVALANCHE_CONTROLLER).centrifugeRecipients(ETHEREUM_DESTINATION_CENTRIFUGE_ID);

        assertEq(centrifugeRecipientAfter, bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    }

    function test_AVALANCHE_onboardCentrifugeJaaaCrosschainTransfer() public onChain(ChainIdUtils.Avalanche()) {
       _testCentrifugeCrosschainTransferOnboarding({
        centrifugeVault         : NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT,
        destinationAddress      : Ethereum.ALM_PROXY,
        destinationCentrifugeId : ETHEREUM_DESTINATION_CENTRIFUGE_ID,
        expectedTransferAmount  : 10_000_000e6,
        maxAmount               : AVALANCHE_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
        slope                   : AVALANCHE_JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
       });
    }

    function test_AVALANCHE_onboardCentrifugeJtrsyCrosschainTransfer() public onChain(ChainIdUtils.Avalanche()) {
       _testCentrifugeCrosschainTransferOnboarding({
        centrifugeVault         : NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT,
        destinationAddress      : Ethereum.ALM_PROXY,
        destinationCentrifugeId : ETHEREUM_DESTINATION_CENTRIFUGE_ID,
        expectedTransferAmount  : 10_000_000e6,
        maxAmount               : AVALANCHE_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
        slope                   : AVALANCHE_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
       });
    }

}
