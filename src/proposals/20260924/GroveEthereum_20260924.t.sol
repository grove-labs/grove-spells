// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { Base }     from "lib/grove-address-registry/src/Base.sol";
import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { IRateLimits as IPauRateLimits } from "diamond-pau/interfaces/IRateLimits.sol";

import { ChainIdUtils }    from "src/libraries/helpers/ChainId.sol";
import { GrovePauHelpers } from "src/libraries/helpers/GrovePauHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

import { IPauBaseControllerLike, PauContext } from "src/test-harness/CommonPauTestBase.sol";

interface IAllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface IVatLike {
    function ilks(bytes32 ilk) external view returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
    function urns(bytes32 ilk, address urn) external view returns (uint256 ink, uint256 art);
}

contract GroveEthereum_20260924_Test is GroveTestBase {

    address internal constant PAYLOAD_ETHEREUM = 0xFB1DEBB9CD8eD442103092C6aCd9ACC231224CFb;
    address internal constant PAYLOAD_BASE     = 0xd3642d91279c58508E9986b8742Ac51eb70BF72e;

    address internal constant GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT = 0xbeef0786756810478b88982DE00F3CD7fdB8e7c7;

    constructor() {
        id = "20260924";
    }

    function setUp() public {
        setupDomains("2026-09-15T15:50:00Z");

        chainData[ChainIdUtils.Ethereum()].payload = PAYLOAD_ETHEREUM;
        chainData[ChainIdUtils.Base()].payload     = PAYLOAD_BASE;
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

    function test_ETHEREUM_setPauUnwindRateLimitsToUnlimited() public onChain(ChainIdUtils.Ethereum()) {
        IPauRateLimits rateLimits = IPauRateLimits(Ethereum.PAU_RATE_LIMITS);

        uint256 burnMaxBefore = rateLimits.getRateLimitData(GrovePauHelpers.LIMIT_USDS_BURN).maxAmount;
        uint256 swapMaxBefore = rateLimits.getRateLimitData(GrovePauHelpers.LIMIT_USDC_TO_USDS).maxAmount;

        // The spec sets these to unlimited from whatever finite value they hold at execution, so the
        // pre-state is asserted as finite rather than as a literal that would rot before the cast.
        assertLt(burnMaxBefore, type(uint256).max, "usds-burn-already-unlimited");
        assertLt(swapMaxBefore, type(uint256).max, "usdc-to-usds-already-unlimited");

        // Unwind sizes sit one million above the finite ceilings in force at the fork block
        // (15_000_000 on 2026-09-11, stepped daily by PAS), so they always exceed the old limits.
        uint256 burnUsds = burnMaxBefore + 1_000_000e18;
        uint256 swapUsdc = swapMaxBefore + 1_000_000e6;

        PauContext memory ctx  = _getPauContext();
        IERC20            usds = IERC20(Ethereum.USDS);
        IERC20            usdc = IERC20(Ethereum.USDC);

        // Burn repays ALLOCATOR-GROVE-A debt, so the vault must owe at least the burn amount.
        IAllocatorVaultLike vault = IAllocatorVaultLike(IPauBaseControllerLike(ctx.controller).usds_vault());

        ( , uint256 art )     = IVatLike(Ethereum.VAT).urns(vault.ilk(), address(vault));
        ( , uint256 rate,,, ) = IVatLike(Ethereum.VAT).ilks(vault.ilk());

        assertGe(art * rate / 1e27, burnUsds, "vault-debt-below-burn-amount");

        deal2(Ethereum.USDS, address(ctx.proxy), burnUsds);
        deal(Ethereum.USDC,  address(ctx.proxy), swapUsdc);

        // --- Before: the finite limits reject the unwind. ---
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.usds_burn, (burnUsds)));

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.psm_swapUSDCToUSDS, (swapUsdc)));

        executeAllPayloadsAndBridges();

        _assertPauUnlimitedRateLimit(GrovePauHelpers.LIMIT_USDS_BURN);
        _assertPauUnlimitedRateLimit(GrovePauHelpers.LIMIT_USDC_TO_USDS);

        // --- After: the same unwind goes through and leaves both limits unlimited. ---
        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.usds_burn, (burnUsds)));

        assertEq(usds.balanceOf(address(ctx.proxy)), 0, "proxy-usds-not-burned");
        assertEq(
            ctx.rateLimits.getCurrentRateLimit(GrovePauHelpers.LIMIT_USDS_BURN),
            type(uint256).max,
            "usds-burn-limit-consumed"
        );

        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.psm_swapUSDCToUSDS, (swapUsdc)));

        assertEq(usdc.balanceOf(address(ctx.proxy)), 0,               "proxy-usdc-not-swapped");
        assertEq(usds.balanceOf(address(ctx.proxy)), swapUsdc * 1e12, "proxy-usds-not-received");
        assertEq(
            ctx.rateLimits.getCurrentRateLimit(GrovePauHelpers.LIMIT_USDC_TO_USDS),
            type(uint256).max,
            "usdc-to-usds-limit-consumed"
        );
    }

    function test_ETHEREUM_pauOutboundRateLimitsUnchanged() public onChain(ChainIdUtils.Ethereum()) {
        IPauRateLimits rateLimits = IPauRateLimits(Ethereum.PAU_RATE_LIMITS);

        IPauRateLimits.RateLimitData memory mintBefore       = rateLimits.getRateLimitData(GrovePauHelpers.LIMIT_USDS_MINT);
        IPauRateLimits.RateLimitData memory usdsToUsdcBefore = rateLimits.getRateLimitData(GrovePauHelpers.LIMIT_USDS_TO_USDC);

        executeAllPayloadsAndBridges();

        IPauRateLimits.RateLimitData memory mintAfter       = rateLimits.getRateLimitData(GrovePauHelpers.LIMIT_USDS_MINT);
        IPauRateLimits.RateLimitData memory usdsToUsdcAfter = rateLimits.getRateLimitData(GrovePauHelpers.LIMIT_USDS_TO_USDC);

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
        assertEq(IERC20(Base.USDC).decimals(),                                 6,  "usdc-decimals-changed");
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
