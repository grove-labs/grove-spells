// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/ChainId.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/GroveLiquidityLayerTests.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface AutoLineLike {
    function exec(bytes32) external;
}

contract GroveEthereum_20251030_Test is GroveTestBase {

    address internal constant CURVE_RLUSDUSDC           = 0xD001aE433f254283FeCE51d4ACcE8c53263aa186;

    address internal constant AAVE_ATOKEN_CORE_USDC     = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address internal constant AAVE_ATOKEN_CORE_RLUSD    = 0xFa82580c16A31D0c1bC632A36F82e83EfEF3Eec0;
    address internal constant AAVE_ATOKEN_HORIZON_USDC  = 0x68215B6533c47ff9f7125aC95adf00fE4a62f79e;
    address internal constant AAVE_ATOKEN_HORIZON_RLUSD = 0xE3190143Eb552456F88464662f0c0C4aC67A77eB;

    uint256 internal constant EXPECTED_SWAP_AMOUNT_TOKEN0  = 50_000e6;
    uint256 internal constant CURVE_RLUSDUSDC_MAX_SLIPPAGE = 0.9990e18;
    uint256 internal constant CURVE_RLUSDUSDC_SWAP_MAX     = 20_000_000e18;
    uint256 internal constant CURVE_RLUSDUSDC_SWAP_SLOPE   = 100_000_000e18 / uint256(1 days);

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

    constructor() {
        id = "20251030";
    }

    function setUp() public {
        setupDomains("2025-10-09T13:00:00Z");

        deployPayloads();
    }

    function test_ETHEREUM_curve_rlusdusdcOnboarding() public onChain(ChainIdUtils.Ethereum()) {
        _testCurveOnboarding({
            pool:                        CURVE_RLUSDUSDC,
            expectedDepositAmountToken0: 0,
            expectedSwapAmountToken0:    EXPECTED_SWAP_AMOUNT_TOKEN0,
            maxSlippage:                 CURVE_RLUSDUSDC_MAX_SLIPPAGE,
            swapMax:                     CURVE_RLUSDUSDC_SWAP_MAX,
            swapSlope:                   CURVE_RLUSDUSDC_SWAP_SLOPE,
            depositMax:                  0,
            depositSlope:                0,
            withdrawMax:                 0,
            withdrawSlope:               0
        });
    }

    function test_ETHEREUM_onboardAaveCoreUsdc() public onChain(ChainIdUtils.Ethereum()) {
        _testAaveOnboarding(
            AAVE_ATOKEN_CORE_USDC,
            AAVE_ATOKEN_CORE_USDC_TEST_DEPOSIT,
            AAVE_ATOKEN_CORE_USDC_DEPOSIT_MAX,
            AAVE_ATOKEN_CORE_USDC_DEPOSIT_SLOPE
        );
    }

    function test_ETHEREUM_onboardAaveCoreRlusd() public onChain(ChainIdUtils.Ethereum()) {
        _testAaveOnboarding(
            AAVE_ATOKEN_CORE_RLUSD,
            AAVE_ATOKEN_CORE_RLUSD_TEST_DEPOSIT,
            AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_MAX,
            AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_SLOPE
        );
    }

    function test_ETHEREUM_onboardAaveHorizonUsdc() public onChain(ChainIdUtils.Ethereum()) {
        _testAaveOnboarding(
            AAVE_ATOKEN_HORIZON_USDC,
            AAVE_ATOKEN_HORIZON_USDC_TEST_DEPOSIT,
            AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_MAX,
            AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_SLOPE
        );
    }

    function test_ETHEREUM_onboardAaveHorizonRlusd() public onChain(ChainIdUtils.Ethereum()) {
        _testAaveOnboarding(
            AAVE_ATOKEN_HORIZON_RLUSD,
            AAVE_ATOKEN_HORIZON_RLUSD_TEST_DEPOSIT,
            AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX,
            AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE
        );
    }

}
