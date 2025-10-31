// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";
import { Plasma }   from "lib/grove-address-registry/src/Plasma.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20251030_Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant MAINNET_SECURITIZE_DEPOSIT_WALLET = 0x51e4C4A356784D0B3b698BFB277C626b2b9fe178;
    address internal constant MAINNET_SECURITIZE_REDEEM_WALLET  = 0xbb543C77436645C8b95B64eEc39E3C0d48D4842b;
    address internal constant MAINNET_SECURITIZE_STAC_CLO       = 0x51C2d74017390CbBd30550179A16A1c28F7210fc;

    address internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBEEf2B5FD3D94469b7782aeBe6364E6e6FB1B709;

    address internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBeEf2d50B428675a1921bC6bBF4bfb9D8cF1461A;

    address internal constant PLASMA_AAVE_CORE_USDT = 0x5D72a9d9A9510Cd8cBdBA12aC62593A58930a948;

    uint256 internal constant MAINNET_SECURITIZE_DEPOSIT_TEST_DEPOSIT  = 50_000_000e6;
    uint256 internal constant MAINNET_SECURITIZE_DEPOSIT_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant MAINNET_SECURITIZE_DEPOSIT_DEPOSIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT  = 20_000_000e6;
    uint256 internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint256 internal constant MAINNET_EXPECTED_SWAP_AMOUNT_TOKEN0    = 50_000e6;
    uint256 internal constant MAINNET_CURVE_RLUSD_USDC_MAX_SLIPPAGE  = 0.9990e18;
    uint256 internal constant MAINNET_CURVE_RLUSD_USDC_SWAP_MAX      = 20_000_000e18;
    uint256 internal constant MAINNET_CURVE_RLUSD_USDC_SWAP_SLOPE    = 100_000_000e18 / uint256(1 days);
    uint256 internal constant MAINNET_EXPECTED_DEPOSIT_AMOUNT_TOKEN0 = 1_000e6;
    uint256 internal constant MAINNET_CURVE_RLUSD_USDC_DEPOSIT_MAX   = 25_000_000e6;
    uint256 internal constant MAINNET_CURVE_RLUSD_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant MAINNET_CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant MAINNET_CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT  = 20_000_000e6;
    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint256 internal constant BASE_CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant BASE_CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant PLASMA_AAVE_CORE_USDT_TEST_DEPOSIT  = 20_000_000e6;
    uint256 internal constant PLASMA_AAVE_CORE_USDT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant PLASMA_AAVE_CORE_USDT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    constructor() {
        id = "20251113";
    }

    function setUp() public {
        setupDomains("2025-10-30T12:00:00Z");

        deployPayloads();
    }

    function test_ETHEREUM_onboardGroveXSteakhouseUsdcMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            expectedDepositAmount : MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardSecuritizeStacCloDeposits() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : MAINNET_SECURITIZE_DEPOSIT_WALLET,
            expectedDepositAmount : MAINNET_SECURITIZE_DEPOSIT_TEST_DEPOSIT,
            depositMax            : MAINNET_SECURITIZE_DEPOSIT_DEPOSIT_MAX,
            depositSlope          : MAINNET_SECURITIZE_DEPOSIT_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardSecuritizeStacCloRedemptions() public onChain(ChainIdUtils.Ethereum()) {
        _assertZeroRateLimit(RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            MAINNET_SECURITIZE_STAC_CLO,
            MAINNET_SECURITIZE_REDEEM_WALLET
        ));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            MAINNET_SECURITIZE_STAC_CLO,
            MAINNET_SECURITIZE_REDEEM_WALLET
        ));

        // TODO: Try fixing. Doesn't work because MAINNET_SECURITIZE_STAC_CLO doesn't work with deal2

        // _testUnlimitedDirectTokenTransferOnboarding({
        //     token                 : MAINNET_SECURITIZE_STAC_CLO,
        //     destination           : MAINNET_SECURITIZE_REDEEM_WALLET,
        //     expectedDepositAmount : MAINNET_SECURITIZE_DEPOSIT_TEST_DEPOSIT
        // });
    }

    function test_ETHEREUM_onboardCurvePoolRlusdUsdcLP() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Fix this test
        revert("Work in progress");

        // Testing full onboarding, including swap configuration introduced in the previous proposal
        _testCurveOnboarding({
            pool                        : Ethereum.CURVE_RLUSD_USDC,
            expectedDepositAmountToken0 : MAINNET_EXPECTED_DEPOSIT_AMOUNT_TOKEN0,
            expectedSwapAmountToken0    : 0, // MAINNET_EXPECTED_SWAP_AMOUNT_TOKEN0,   // TODO Use proper values after previous proposal is executed
            maxSlippage                 : 0, // MAINNET_CURVE_RLUSD_USDC_MAX_SLIPPAGE, // TODO Use proper values after previous proposal is executed
            swapMax                     : 0, // MAINNET_CURVE_RLUSD_USDC_SWAP_MAX,     // TODO Use proper values after previous proposal is executed
            swapSlope                   : 0, // MAINNET_CURVE_RLUSD_USDC_SWAP_SLOPE,   // TODO Use proper values after previous proposal is executed
            depositMax                  : MAINNET_CURVE_RLUSD_USDC_DEPOSIT_MAX,
            depositSlope                : MAINNET_CURVE_RLUSD_USDC_DEPOSIT_SLOPE,
            withdrawMax                 : type(uint256).max,
            withdrawSlope               : 0
        });
    }

    function test_ETHEREUM_onboardCctpTransfersToBase() public onChain(ChainIdUtils.Ethereum()) {
        revert("Not implemented");
        // TODO: Implement
    }

    function test_BASE_governanceDeployment() public onChain(ChainIdUtils.Base()) {
        _verifyForeignDomainExecutorDeployment({
            _executor : Base.GROVE_EXECUTOR,
            _receiver : Base.GROVE_RECEIVER,
            _deployer : DEPLOYER
        });
        _verifyArbitrumReceiverDeployment({
            _executor : Base.GROVE_EXECUTOR,
            _receiver : Base.GROVE_RECEIVER
        });
    }

    function test_BASE_almSystemDeployment() public onChain(ChainIdUtils.Base()) {
        _verifyForeignAlmSystemDeployment(
            AlmSystemContracts({
                admin      : Base.GROVE_EXECUTOR,
                proxy      : Base.ALM_PROXY,
                rateLimits : Base.ALM_RATE_LIMITS,
                controller : Base.ALM_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
                freezer  : Base.ALM_FREEZER,
                relayer  : Base.ALM_RELAYER
            }),
            ForeignAlmSystemDependencies({
                cctp : Base.CCTP_TOKEN_MESSENGER,
                psm  : Base.PSM3,
                usdc : Base.USDC
            })
        );
    }

    function test_BASE_onboardGroveXSteakhouseUsdcMorphoVault() public onChain(ChainIdUtils.Base()) {
        _testERC4626Onboarding({
            vault                 : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            expectedDepositAmount : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

    function test_BASE_onboardCctpTransfersToEthereum() public onChain(ChainIdUtils.Base()) {
        revert("Not implemented");
        // TODO: Implement
    }

    function test_PLASMA_governanceDeployment() public onChain(ChainIdUtils.Plasma()) {
        _verifyForeignDomainExecutorDeployment({
            _executor : Plasma.GROVE_EXECUTOR,
            _receiver : Plasma.GROVE_RECEIVER,
            _deployer : DEPLOYER
        });

        _verifyLayerZeroReceiverDeployment({
            _executor : Plasma.GROVE_EXECUTOR,
            _receiver : Plasma.GROVE_RECEIVER
        });
    }

    function test_PLASMA_almSystemDeployment() public onChain(ChainIdUtils.Plasma()) {
        _verifyForeignAlmSystemDeployment(
            AlmSystemContracts({
                admin      : Plasma.GROVE_EXECUTOR,
                proxy      : Plasma.ALM_PROXY,
                rateLimits : Plasma.ALM_RATE_LIMITS,
                controller : Plasma.ALM_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
                freezer  : Plasma.ALM_FREEZER,
                relayer  : Plasma.ALM_RELAYER
            }),
            ForeignAlmSystemDependencies({
                psm  : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                usdc : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                cctp : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER
            })
        );
    }

    function test_PLASMA_onboardAaveCoreUsdt() public onChain(ChainIdUtils.Plasma()) {
        _testAaveOnboarding({
            aToken                : PLASMA_AAVE_CORE_USDT,
            expectedDepositAmount : PLASMA_AAVE_CORE_USDT_TEST_DEPOSIT,
            depositMax            : PLASMA_AAVE_CORE_USDT_DEPOSIT_MAX,
            depositSlope          : PLASMA_AAVE_CORE_USDT_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_BASE_cctpTransferE2E() public onChain(ChainIdUtils.Ethereum()) {
        revert("Not implemented");
        // TODO: Implement
    }

}
