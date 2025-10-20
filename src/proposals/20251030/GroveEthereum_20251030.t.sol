// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ChainIdUtils } from "src/libraries/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20251030_Test is GroveTestBase {

    address internal constant CURVE_RLUSD_USDC = 0xD001aE433f254283FeCE51d4ACcE8c53263aa186;

    address internal constant AAVE_ATOKEN_CORE_USDC     = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address internal constant AAVE_ATOKEN_CORE_RLUSD    = 0xFa82580c16A31D0c1bC632A36F82e83EfEF3Eec0;
    address internal constant AAVE_ATOKEN_HORIZON_USDC  = 0x68215B6533c47ff9f7125aC95adf00fE4a62f79e;
    address internal constant AAVE_ATOKEN_HORIZON_RLUSD = 0xE3190143Eb552456F88464662f0c0C4aC67A77eB;

    uint256 internal constant EXPECTED_SWAP_AMOUNT_TOKEN0   = 50_000e6;
    uint256 internal constant CURVE_RLUSD_USDC_MAX_SLIPPAGE = 0.9990e18;
    uint256 internal constant CURVE_RLUSD_USDC_SWAP_MAX     = 20_000_000e18;
    uint256 internal constant CURVE_RLUSD_USDC_SWAP_SLOPE   = 100_000_000e18 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_CORE_USDC_TEST_DEPOSIT  = 1_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_TEST_DEPOSIT  = 1_000_000e18;
    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_MAX   = 50_000_000e18;
    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_SLOPE = 25_000_000e18 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_TEST_DEPOSIT  = 1_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_TEST_DEPOSIT  = 0; // No supply cap currently available for this pool
    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX   = 50_000_000e18;
    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE = 25_000_000e18 / uint256(1 days);

    constructor() {
        id = "20251030";
    }

    function setUp() public {
        setupDomains("2025-10-19T16:00:00Z");

        deployPayloads();
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
        _testAaveOnboarding({
            aToken                : AAVE_ATOKEN_HORIZON_RLUSD,
            expectedDepositAmount : AAVE_ATOKEN_HORIZON_RLUSD_TEST_DEPOSIT,
            depositMax            : AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX,
            depositSlope          : AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE
        });
    }

}
