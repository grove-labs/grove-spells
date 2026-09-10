// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { Base }     from "lib/grove-address-registry/src/Base.sol";
import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { IRateLimits as IPauRateLimits } from "diamond-pau/interfaces/IRateLimits.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260924_Test is GroveTestBase {

    address internal constant BUIDLI_GROVE_BASIN = 0xf1615aC3181a4a28D35fB2b9cea84dd4a199B9D7;

    address internal constant GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT = 0xbeef0786756810478b88982DE00F3CD7fdB8e7c7;

    bytes32 internal constant LIMIT_USDS_BURN    = keccak256("LIMIT_USDS_BURN");
    bytes32 internal constant LIMIT_USDS_MINT    = keccak256("LIMIT_USDS_MINT");
    bytes32 internal constant LIMIT_USDC_TO_USDS = keccak256("LIMIT_USDC_TO_USDS");
    bytes32 internal constant LIMIT_USDS_TO_USDC = keccak256("LIMIT_USDS_TO_USDC");

    constructor() {
        id = "20260924";
    }

    function setUp() public {
        setupDomains("2026-09-10T17:28:00Z");

        deployPayloads();
    }

    function test_ETHEREUM_treasuryDistributionToGroveFoundation() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 subProxyUsdsStart   = usds.balanceOf(Ethereum.GROVE_PROXY);
        uint256 foundationUsdsStart = usds.balanceOf(Ethereum.GROVE_FOUNDATION);

        assertGe(subProxyUsdsStart, 800_000e18, "grove-proxy-insufficient-usds-balance");

        executeAllPayloadsAndBridges();

        assertEq(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            subProxyUsdsStart - 800_000e18,
            "grove-proxy-usds-not-decreased"
        );

        assertEq(
            usds.balanceOf(Ethereum.GROVE_FOUNDATION),
            foundationUsdsStart + 800_000e18,
            "foundation-usds-balance-not-increased"
        );
    }

    function test_ETHEREUM_onboardBuidlIBasin() public onChain(ChainIdUtils.Ethereum()) {
        _testBasinOnboarding({
            basin                 : BUIDLI_GROVE_BASIN,
            swapToken             : Ethereum.USDS,
            collateralToken       : Ethereum.USDC,
            expectedDepositAmount : 1_000_000e18,
            depositMax            : 5_000_000e18,
            depositSlope          : 5_000_000e18 / uint256(1 days)
        });
    }

    function test_ETHEREUM_setDpauUnwindRateLimitsToUnlimited() public onChain(ChainIdUtils.Ethereum()) {
        IPauRateLimits rateLimits = IPauRateLimits(Ethereum.PAU_RATE_LIMITS);

        // The spec sets these to unlimited from whatever finite value they hold at execution, so the
        // pre-state is asserted as finite rather than as a literal that would rot before the cast.
        assertLt(
            rateLimits.getRateLimitData(LIMIT_USDS_BURN).maxAmount,
            type(uint256).max,
            "usds-burn-already-unlimited"
        );
        assertLt(
            rateLimits.getRateLimitData(LIMIT_USDC_TO_USDS).maxAmount,
            type(uint256).max,
            "usdc-to-usds-already-unlimited"
        );

        executeAllPayloadsAndBridges();

        _assertPauUnlimitedRateLimit(LIMIT_USDS_BURN);
        _assertPauUnlimitedRateLimit(LIMIT_USDC_TO_USDS);
    }

    function test_ETHEREUM_dpauOutboundRateLimitsUnchanged() public onChain(ChainIdUtils.Ethereum()) {
        IPauRateLimits rateLimits = IPauRateLimits(Ethereum.PAU_RATE_LIMITS);

        IPauRateLimits.RateLimitData memory mintBefore       = rateLimits.getRateLimitData(LIMIT_USDS_MINT);
        IPauRateLimits.RateLimitData memory usdsToUsdcBefore = rateLimits.getRateLimitData(LIMIT_USDS_TO_USDC);

        executeAllPayloadsAndBridges();

        IPauRateLimits.RateLimitData memory mintAfter       = rateLimits.getRateLimitData(LIMIT_USDS_MINT);
        IPauRateLimits.RateLimitData memory usdsToUsdcAfter = rateLimits.getRateLimitData(LIMIT_USDS_TO_USDC);

        assertEq(mintAfter.maxAmount, mintBefore.maxAmount, "usds-mint-max-changed");
        assertEq(mintAfter.slope,     mintBefore.slope,     "usds-mint-slope-changed");

        assertEq(usdsToUsdcAfter.maxAmount, usdsToUsdcBefore.maxAmount, "usds-to-usdc-max-changed");
        assertEq(usdsToUsdcAfter.slope,     usdsToUsdcBefore.slope,     "usds-to-usdc-slope-changed");
    }

    function test_BASE_onboardGroveXSteakhouseUsdcV2MorphoVault() public onChain(ChainIdUtils.Base()) {
        assertEq(
            IERC4626(GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT).asset(),
            Base.USDC,
            "vault-asset-not-usdc"
        );
        assertEq(IERC20(Base.USDC).decimals(),                                6, "usdc-decimals-changed");
        assertEq(IERC4626(GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT).decimals(), 18, "vault-decimals-changed");

        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT,
            expectedDepositAmount : 20_000_000e6,
            depositMax            : 20_000_000e6,
            depositSlope          : 20_000_000e6 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 1.15e6
        });
    }

}
