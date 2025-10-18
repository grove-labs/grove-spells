// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { ChainIdUtils }   from "src/libraries/ChainId.sol";
import { CastingHelpers } from "src/libraries/CastingHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20251030_Test is GroveTestBase {

    address internal constant NEW_MAINNET_CONTROLLER = 0x0D142e958B56f44C8B745A2D36F218053addF683;
    address internal constant DEPLOYER               = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant CURVE_RLUSD_USDC = 0xD001aE433f254283FeCE51d4ACcE8c53263aa186;

    address internal constant AAVE_ATOKEN_CORE_USDC     = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address internal constant AAVE_ATOKEN_CORE_RLUSD    = 0xFa82580c16A31D0c1bC632A36F82e83EfEF3Eec0;
    address internal constant AAVE_ATOKEN_HORIZON_USDC  = 0x68215B6533c47ff9f7125aC95adf00fE4a62f79e;
    address internal constant AAVE_ATOKEN_HORIZON_RLUSD = 0xE3190143Eb552456F88464662f0c0C4aC67A77eB;

    uint256 internal constant EXPECTED_SWAP_AMOUNT_TOKEN0  = 50_000e6;
    uint256 internal constant CURVE_RLUSD_USDC_MAX_SLIPPAGE = 0.9990e18;
    uint256 internal constant CURVE_RLUSD_USDC_SWAP_MAX     = 20_000_000e18;
    uint256 internal constant CURVE_RLUSD_USDC_SWAP_SLOPE   = 100_000_000e18 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_CORE_USDC_TEST_DEPOSIT  = 1_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_TEST_DEPOSIT  = 1_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_TEST_DEPOSIT  = 1_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_TEST_DEPOSIT  = 1_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint16 internal constant AVALANCHE_DESTINATION_CENTRIFUGE_ID = 5;
    uint16 internal constant PLUME_DESTINATION_CENTRIFUGE_ID     = 4;

    constructor() {
        id = "20251030";
    }

    function setUp() public {
        setupDomains("2025-10-17T23:45:00Z");

        deployPayloads();

        // Prepare testing setup for the controller upgrade
        chainData[ChainIdUtils.Ethereum()].newController = NEW_MAINNET_CONTROLLER;
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

    function test_ETHEREUM_crosschainTransferRecipients() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 avalancheCctpRecipientBefore       = MainnetController(NEW_MAINNET_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE);
        bytes32 avalancheCentrifugeRecipientBefore = MainnetController(NEW_MAINNET_CONTROLLER).centrifugeRecipients(AVALANCHE_DESTINATION_CENTRIFUGE_ID);
        bytes32 plumeCentrifugeRecipientBefore     = MainnetController(NEW_MAINNET_CONTROLLER).centrifugeRecipients(PLUME_DESTINATION_CENTRIFUGE_ID);

        assertEq(avalancheCctpRecipientBefore,       bytes32(0));
        assertEq(avalancheCentrifugeRecipientBefore, bytes32(0));
        assertEq(plumeCentrifugeRecipientBefore,     bytes32(0));

        executeAllPayloadsAndBridges();

        bytes32 avalancheCctpRecipientAfter       = MainnetController(NEW_MAINNET_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE);
        bytes32 avalancheCentrifugeRecipientAfter = MainnetController(NEW_MAINNET_CONTROLLER).centrifugeRecipients(AVALANCHE_DESTINATION_CENTRIFUGE_ID);
        bytes32 plumeCentrifugeRecipientAfter     = MainnetController(NEW_MAINNET_CONTROLLER).centrifugeRecipients(PLUME_DESTINATION_CENTRIFUGE_ID);

        assertEq(avalancheCctpRecipientAfter,       CastingHelpers.addressToCctpRecipient(Avalanche.ALM_PROXY));
        assertEq(avalancheCentrifugeRecipientAfter, CastingHelpers.addressToCentrifugeRecipient(Avalanche.ALM_PROXY));
        assertEq(plumeCentrifugeRecipientAfter,     CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY));
    }

    function test_ETHEREUM_curveRlusdUsdcOnboarding() public onChain(ChainIdUtils.Ethereum()) {
        _testCurveOnboarding({
            pool                        : CURVE_RLUSD_USDC,
            expectedDepositAmountToken0 : 0,
            expectedSwapAmountToken0    : EXPECTED_SWAP_AMOUNT_TOKEN0,
            maxSlippage                 : CURVE_RLUSD_USDC_MAX_SLIPPAGE,
            swapMax                     : CURVE_RLUSD_USDC_SWAP_MAX,
            swapSlope                   : CURVE_RLUSD_USDC_SWAP_SLOPE,
            depositMax                  : 0,
            depositSlope                : 0,
            withdrawMax                 : 0,
            withdrawSlope               : 0
        });
    }

    function test_ETHEREUM_onboardAaveCoreUsdc() public onChain(ChainIdUtils.Ethereum()) {
        _testAaveOnboarding({
            aToken                : AAVE_ATOKEN_CORE_USDC,
            expectedDepositAmount : AAVE_ATOKEN_CORE_USDC_TEST_DEPOSIT,
            depositMax            : AAVE_ATOKEN_CORE_USDC_DEPOSIT_MAX,
            depositSlope          : AAVE_ATOKEN_CORE_USDC_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardAaveCoreRlusd() public onChain(ChainIdUtils.Ethereum()) {
        _testAaveOnboarding({
            aToken                : AAVE_ATOKEN_CORE_RLUSD,
            expectedDepositAmount : AAVE_ATOKEN_CORE_RLUSD_TEST_DEPOSIT,
            depositMax            : AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_MAX,
            depositSlope          : AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardAaveHorizonUsdc() public onChain(ChainIdUtils.Ethereum()) {
        _testAaveOnboarding({
            aToken                : AAVE_ATOKEN_HORIZON_USDC,
            expectedDepositAmount : AAVE_ATOKEN_HORIZON_USDC_TEST_DEPOSIT,
            depositMax            : AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_MAX,
            depositSlope          : AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardAaveHorizonRlusd() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: At the current block Aave supply cap is reached for this pool. Roll block or make tests account for this.
        vm.skip(true);
        _testAaveOnboarding({
            aToken                : AAVE_ATOKEN_HORIZON_RLUSD,
            expectedDepositAmount : AAVE_ATOKEN_HORIZON_RLUSD_TEST_DEPOSIT,
            depositMax            : AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX,
            depositSlope          : AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardSUsdePT27Nov2025Redemptions() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardUsdePT27Nov2025Redemptions() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

}
