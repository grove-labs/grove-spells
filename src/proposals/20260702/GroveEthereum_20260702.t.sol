// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

import {
    IPauBaseControllerLike,
    IPauProxyLike,
    IPauAccessControlsLike,
    IPauRateLimitsLike,
    PauContext
} from "src/test-harness/CommonPauTestBase.sol";

// --- Sky allocator instance (dss-allocator) ---

interface IAllocatorVaultLike {
    function wards(address usr) external view returns (uint256);
    function buffer() external view returns (address);
    function ilk() external view returns (bytes32);
}

// --- New PAU controller facets ---

interface IPauControllerLike is IPauBaseControllerLike {
    function basin_deposit(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external returns (uint256 shares);
}

interface IAdministeredAgentMembersLike {
    function adminCount() external view returns (uint256);
    function actorCount() external view returns (uint256);
    function revokerCount() external view returns (uint256);
    function getAdmin(uint256 index) external view returns (address);
    function getActor(uint256 index) external view returns (address);
    function getRevoker(uint256 index) external view returns (address);
}

interface ILitePsmLike {
    function kiss(address usr) external;
}

contract GroveEthereum_20260702_Test is GroveTestBase {

    // New Sky ALLOCATOR-GROVE-A instance (deployed by Sky's 2026-06-18 spell).
    address internal constant ALLOCATOR_GROVE_A_VAULT  = 0xf739a30c74927dc6cFA3B67E4933872a1FC5F4EB;
    address internal constant ALLOCATOR_GROVE_A_BUFFER = 0x436DABce608f73BeA2b75fba35bffe72739697d5;

    // New PAU system, onboarded in parallel to the legacy ALM system.
    address internal constant PAU_PROXY                      = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;
    address internal constant PAU_CONTROLLER                 = 0xbf83F5974B932c7D842254042717D6A2706CE5eE;
    address internal constant PAU_ACCESS_CONTROLS            = 0x4F6d1704700cd494DD4cd9bF59c0C39DA1Bc9164;
    address internal constant PAU_RATE_LIMITS                = 0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1;
    address internal constant PAU_ADMINISTERED_AGENT         = 0xdBD17832df0e57b1732cE1C84c652E820e549BAa;
    address internal constant PAU_BEACON                     = 0x829dC2b7E94B1954F0764E573f2E0d45Afa28199;
    address internal constant PAU_FACTORY                    = 0x69A5d548830AC2A4Ba90A44a2C75BDA71f97fc66;
    address internal constant PAU_ADMINISTERED_AGENT_FACTORY = 0x2968c3b5478cF93B70aB1e24255d4EDBBd27a089;
    address internal constant PAU_DEFAULT_ASSEMBLER          = 0xc812aAD3FaE2D3511C664374B601a9BeBFeCCa2E;
    address internal constant PAU_BASIN_FACET                = 0xC84825BCD13AEddc372400239499380376a44A39;
    address internal constant PAU_PSM_FACET                  = 0xE4A5dAc768a310cc2316f258901b32E499653064;
    address internal constant PAU_USDS_FACET                 = 0x1221CC4B85Ab260660aD21C2829e0EB516dffBc7;

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    uint256 internal constant USDS_MINT_MAX      = 5_000_000e18;
    uint256 internal constant USDS_MINT_SLOPE    = 5_000_000e18 / uint256(1 days);
    uint256 internal constant USDS_BURN_MAX      = 5_000_000e18;
    uint256 internal constant USDS_BURN_SLOPE    = 5_000_000e18 / uint256(1 days);
    uint256 internal constant USDS_TO_USDC_MAX   = 5_000_000e6;
    uint256 internal constant USDS_TO_USDC_SLOPE = 5_000_000e6 / uint256(1 days);
    uint256 internal constant USDC_TO_USDS_MAX   = 5_000_000e6;
    uint256 internal constant USDC_TO_USDS_SLOPE = 5_000_000e6 / uint256(1 days);

    address internal constant JTRSY_GROVE_BASIN = 0xf08943f817e1F902dEbC884c7B19Ea5764594Ac9;
    address internal constant BUIDL_GROVE_BASIN = 0xCBa428fB052B365557DAf52b744DFfF20d5FbEdD;

    uint256 internal constant JTRSY_BASIN_DEPOSIT_MAX   = 5_000_000e18;
    uint256 internal constant JTRSY_BASIN_DEPOSIT_SLOPE = 5_000_000e18 / uint256(1 days);
    uint256 internal constant BUIDL_BASIN_DEPOSIT_MAX   = 5_000_000e18;
    uint256 internal constant BUIDL_BASIN_DEPOSIT_SLOPE = 5_000_000e18 / uint256(1 days);

    // USDS amount driven through the basin onboarding lifecycle (within mint (5M) and deposit (5M) limits).
    uint256 internal constant BASIN_DEPOSIT_TEST_AMOUNT = 1_000_000e18;

    // Mirrors the payload: SubProxy USDC->USDS PSM swap amount, and the Grove Foundation distribution.
    uint256 internal constant SUBPROXY_PSM_SWAP_USDC      = 1_102_056_359999;
    uint256 internal constant GROVE_FOUNDATION_USDS_GRANT = 800_000e18;

    constructor() {
        id = "20260702";
    }

    function setUp() public {
        setupDomains("2026-06-22T14:35:00Z");
        deployPayloads();

        _setPauContext(
            ChainIdUtils.Ethereum(),
            PauContext({
                controller     : PAU_CONTROLLER,
                proxy          : IPauProxyLike(PAU_PROXY),
                accessControls : IPauAccessControlsLike(PAU_ACCESS_CONTROLS),
                rateLimits     : IPauRateLimitsLike(PAU_RATE_LIMITS),
                agent          : PAU_ADMINISTERED_AGENT,
                actor          : Ethereum.ALM_RELAYER
            })
        );

        // The ALLOCATOR-GROVE-A ilk init is already live on-chain (Sky's 2026-06-18 spell).
        // Only the PAU proxy's Lite PSM whitelisting is still pending (Sky's 2026-07-02 Core
        // spell), so replay just that here to make the operational swap tests work.
        vm.prank(Ethereum.PAUSE_PROXY);
        ILitePsmLike(Ethereum.PSM).kiss(PAU_PROXY);
    }

    function test_ETHEREUM_pauSystemPreconfiguration() public onChain(ChainIdUtils.Ethereum()) {
        IPauControllerLike      controller    = IPauControllerLike(PAU_CONTROLLER);
        IPauAccessControlsLike accessControls = IPauAccessControlsLike(PAU_ACCESS_CONTROLS);
        IAdministeredAgentMembersLike agent   = IAdministeredAgentMembersLike(PAU_ADMINISTERED_AGENT);

        // Deployments exist
        assertGt(PAU_CONTROLLER.code.length,                 0, "controller-not-deployed");
        assertGt(PAU_PROXY.code.length,                      0, "proxy-not-deployed");
        assertGt(PAU_ACCESS_CONTROLS.code.length,            0, "access-controls-not-deployed");
        assertGt(PAU_RATE_LIMITS.code.length,                0, "rate-limits-not-deployed");
        assertGt(PAU_ADMINISTERED_AGENT.code.length,         0, "administered-agent-not-deployed");
        assertGt(PAU_ADMINISTERED_AGENT_FACTORY.code.length, 0, "administered-agent-factory-not-deployed");
        assertGt(PAU_DEFAULT_ASSEMBLER.code.length,          0, "default-assembler-not-deployed");
        assertGt(PAU_BASIN_FACET.code.length,                0, "basin-facet-not-deployed");
        assertGt(PAU_PSM_FACET.code.length,                  0, "psm-facet-not-deployed");
        assertGt(PAU_USDS_FACET.code.length,                 0, "usds-facet-not-deployed");

        // Controller wiring (now points at the new PAU proxy / rate limits, not the legacy ALM system)
        assertEq(controller.accessControls(), PAU_ACCESS_CONTROLS, "controller-access-controls-mismatch");
        assertEq(controller.beacon(),         PAU_BEACON,          "controller-beacon-mismatch");
        assertEq(controller.proxy(),          PAU_PROXY,           "controller-proxy-mismatch");
        assertEq(controller.rateLimits(),     PAU_RATE_LIMITS,     "controller-rate-limits-mismatch");

        // The PAU factory grants the controller the CONTROLLER role on its own proxy + rate limits
        // at deployment, so the payload does not need to; the mint/swap/basin tests confirm it stays
        // operational after the spell.
        assertTrue(IPauProxyLike(PAU_PROXY).hasRole(CONTROLLER, PAU_CONTROLLER),            "controller-missing-proxy-role");
        assertTrue(IPauRateLimitsLike(PAU_RATE_LIMITS).hasRole(CONTROLLER, PAU_CONTROLLER), "controller-missing-rate-limits-role");

        // Facet dispatch wiring
        assertEq(controller.getDispatch(IPauControllerLike.basin_deposit.selector).facet,          PAU_BASIN_FACET, "basin-facet-not-wired");
        assertEq(controller.getDispatch(IPauBaseControllerLike.usds_mint.selector).facet,          PAU_USDS_FACET,  "usds-facet-not-wired");
        assertEq(controller.getDispatch(IPauBaseControllerLike.psm_swapUSDSToUSDC.selector).facet, PAU_PSM_FACET,   "psm-facet-not-wired");

        // Access controls: the Grove SubProxy is the sole admin; the agent is an allocator
        assertTrue(accessControls.hasRole(DEFAULT_ADMIN_ROLE, Ethereum.GROVE_PROXY), "subproxy-missing-admin-role");
        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1,           "admin-role-member-count");
        assertFalse(accessControls.hasRole(DEFAULT_ADMIN_ROLE, PAU_FACTORY),         "factory-still-admin");
        assertTrue(accessControls.hasRole(ALLOCATOR_ROLE, PAU_ADMINISTERED_AGENT),   "agent-missing-allocator-role");

        // Agent membership (same as the legacy ALM relayer set)
        assertEq(agent.adminCount(),   1, "agent-admin-count");
        assertEq(agent.actorCount(),   3, "agent-actor-count");
        assertEq(agent.revokerCount(), 1, "agent-revoker-count");

        assertEq(agent.getAdmin(0),   Ethereum.GROVE_PROXY,                      "agent-admin-0");
        assertEq(agent.getActor(0),   Ethereum.ALM_RELAYER,                      "agent-actor-0");
        assertEq(agent.getActor(1),   Ethereum.GROVE_PRIMARY_RELAYER_OPERATOR,   "agent-actor-1");
        assertEq(agent.getActor(2),   Ethereum.GROVE_SECONDARY_RELAYER_OPERATOR, "agent-actor-2");
        assertEq(agent.getRevoker(0), Ethereum.ALM_FREEZER,                      "agent-revoker-0");
    }

    function test_ETHEREUM_initPauSystem() public onChain(ChainIdUtils.Ethereum()) {
        IAllocatorVaultLike vault     = IAllocatorVaultLike(ALLOCATOR_GROVE_A_VAULT);
        IERC20              usds      = IERC20(Ethereum.USDS);
        IPauControllerLike controller = IPauControllerLike(PAU_CONTROLLER);

        assertEq(vault.ilk(),             GROVE_PAU_ALLOCATOR_ILK,  "vault-ilk-mismatch");
        assertEq(vault.buffer(),          ALLOCATOR_GROVE_A_BUFFER, "vault-buffer-mismatch");
        assertEq(controller.usds_vault(), address(0),               "controller-already-has-vault");

        assertEq(vault.wards(PAU_PROXY),                              0, "proxy-already-vault-ward");
        assertEq(usds.allowance(ALLOCATOR_GROVE_A_BUFFER, PAU_PROXY), 0, "proxy-already-has-buffer-allowance");

        executeAllPayloadsAndBridges();

        assertEq(vault.ilk(),             GROVE_PAU_ALLOCATOR_ILK,  "vault-ilk-mismatch");
        assertEq(vault.buffer(),          ALLOCATOR_GROVE_A_BUFFER, "vault-buffer-mismatch");
        assertEq(controller.usds_vault(), ALLOCATOR_GROVE_A_VAULT,  "controller-vault-not-set");

        assertEq(vault.wards(PAU_PROXY),                              1,                 "proxy-not-vault-ward");
        assertEq(usds.allowance(ALLOCATOR_GROVE_A_BUFFER, PAU_PROXY), type(uint256).max, "proxy-missing-buffer-allowance");
    }

    function test_ETHEREUM_onboardUsdsMintBurnToPau() public onChain(ChainIdUtils.Ethereum()) {
        IPauControllerLike controller = IPauControllerLike(PAU_CONTROLLER);

        bytes32 mintKey = controller.usds_mintRateLimitKey();
        bytes32 burnKey = controller.usds_burnRateLimitKey();

        // --- Before: mint + burn limits unset. ---
        _assertPauZeroRateLimit(mintKey);
        _assertPauZeroRateLimit(burnKey);

        executeAllPayloadsAndBridges();

        // --- After: mint + burn limits set to the onboarded values. ---
        _assertPauRateLimit(mintKey, USDS_MINT_MAX, USDS_MINT_SLOPE);
        _assertPauRateLimit(burnKey, USDS_BURN_MAX, USDS_BURN_SLOPE);

        // --- Operational: mint USDS through ALLOCATOR-GROVE-A, then burn it back. ---
        PauContext memory ctx  = _getPauContext();
        IERC20            usds = IERC20(Ethereum.USDS);

        uint256 proxyUsdsStart = usds.balanceOf(address(ctx.proxy));
        uint256 amount         = 1_000_000e18;

        assertEq(ctx.rateLimits.getCurrentRateLimit(mintKey), USDS_MINT_MAX, "mint-rate-limit-not-full");
        assertEq(ctx.rateLimits.getCurrentRateLimit(burnKey), USDS_BURN_MAX, "burn-rate-limit-not-full");

        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.usds_mint, (amount)));

        assertEq(usds.balanceOf(address(ctx.proxy)),          proxyUsdsStart + amount, "proxy-usds-not-minted");
        assertEq(ctx.rateLimits.getCurrentRateLimit(mintKey), USDS_MINT_MAX - amount,  "mint-rate-limit-not-decreased");

        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.usds_burn, (amount)));

        assertEq(usds.balanceOf(address(ctx.proxy)),          proxyUsdsStart,         "proxy-usds-not-burned");
        assertEq(ctx.rateLimits.getCurrentRateLimit(burnKey), USDS_BURN_MAX - amount, "burn-rate-limit-not-decreased");
    }

    function test_ETHEREUM_onboardPsmSwapToPau() public onChain(ChainIdUtils.Ethereum()) {
        IPauControllerLike controller = IPauControllerLike(PAU_CONTROLLER);

        bytes32 usdsToUsdcKey = controller.psm_usdsToUSDCSwapRateLimitKey();
        bytes32 usdcToUsdsKey = controller.psm_usdcToUSDSSwapRateLimitKey();

        // --- Before: both swap limits unset. ---
        _assertPauZeroRateLimit(usdsToUsdcKey);
        _assertPauZeroRateLimit(usdcToUsdsKey);

        executeAllPayloadsAndBridges();

        // --- After: both swap limits set to the onboarded values. ---
        _assertPauRateLimit(usdsToUsdcKey, USDS_TO_USDC_MAX, USDS_TO_USDC_SLOPE);
        _assertPauRateLimit(usdcToUsdsKey, USDC_TO_USDS_MAX, USDC_TO_USDS_SLOPE);

        // --- Operational: mint USDS, swap it to USDC and back through the PSM, then burn it. ---
        PauContext memory ctx  = _getPauContext();
        IERC20            usds = IERC20(Ethereum.USDS);
        IERC20            usdc = IERC20(Ethereum.USDC);

        uint256 proxyUsdsStart = usds.balanceOf(address(ctx.proxy));
        uint256 proxyUsdcStart = usdc.balanceOf(address(ctx.proxy));

        uint256 swapUsdc = 1_000_000e6;      // 1M USDC
        uint256 swapUsds = swapUsdc * 1e12;  // 1M USDS equivalent (0 PSM fee)

        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.usds_mint, (swapUsds)));

        assertEq(usds.balanceOf(address(ctx.proxy)), proxyUsdsStart + swapUsds, "proxy-usds-not-minted");
        assertEq(usdc.balanceOf(address(ctx.proxy)), proxyUsdcStart,            "proxy-usdc-changed-by-mint");

        // Forward: USDS -> USDC (decreases the usds-to-usdc limit).
        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.psm_swapUSDSToUSDC, (swapUsdc)));

        assertEq(usds.balanceOf(address(ctx.proxy)), proxyUsdsStart,            "proxy-usds-not-spent");
        assertEq(usdc.balanceOf(address(ctx.proxy)), proxyUsdcStart + swapUsdc, "proxy-usdc-not-received");

        assertEq(ctx.rateLimits.getCurrentRateLimit(usdsToUsdcKey), USDS_TO_USDC_MAX - swapUsdc, "usds-to-usdc-limit-not-decreased");
        assertEq(ctx.rateLimits.getCurrentRateLimit(usdcToUsdsKey), USDC_TO_USDS_MAX,            "usdc-to-usds-limit-changed-on-forward");

        // Reverse: USDC -> USDS (refills the usds-to-usdc limit, decreases the usdc-to-usds limit).
        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.psm_swapUSDCToUSDS, (swapUsdc)));

        assertEq(usdc.balanceOf(address(ctx.proxy)), proxyUsdcStart,            "proxy-usdc-not-spent");
        assertEq(usds.balanceOf(address(ctx.proxy)), proxyUsdsStart + swapUsds, "proxy-usds-not-returned");

        assertEq(ctx.rateLimits.getCurrentRateLimit(usdsToUsdcKey), USDS_TO_USDC_MAX,            "usds-to-usdc-limit-not-refilled");
        assertEq(ctx.rateLimits.getCurrentRateLimit(usdcToUsdsKey), USDC_TO_USDS_MAX - swapUsdc, "usdc-to-usds-limit-not-decreased");

        // Burn the round-tripped USDS, closing out the position.
        _callAsPauActor(ctx, abi.encodeCall(IPauBaseControllerLike.usds_burn, (swapUsds)));

        assertEq(usds.balanceOf(address(ctx.proxy)), proxyUsdsStart, "proxy-usds-not-burned");
    }

    function test_ETHEREUM_onboardJtrsyBasin() public onChain(ChainIdUtils.Ethereum()) {
        _testBasinOnboarding({
            basin                 : JTRSY_GROVE_BASIN,
            swapToken             : Ethereum.USDS,
            collateralToken       : Ethereum.USDC,
            expectedDepositAmount : BASIN_DEPOSIT_TEST_AMOUNT,
            depositMax            : JTRSY_BASIN_DEPOSIT_MAX,
            depositSlope          : JTRSY_BASIN_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardBuidlBasin() public onChain(ChainIdUtils.Ethereum()) {
        _testBasinOnboarding({
            basin                 : BUIDL_GROVE_BASIN,
            swapToken             : Ethereum.USDS,
            collateralToken       : Ethereum.USDC,
            expectedDepositAmount : BASIN_DEPOSIT_TEST_AMOUNT,
            depositMax            : BUIDL_BASIN_DEPOSIT_MAX,
            depositSlope          : BUIDL_BASIN_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_swapUsdcToUsdsViaPsm() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usdc = IERC20(Ethereum.USDC);

        uint256 subProxyUsdcStart = usdc.balanceOf(Ethereum.GROVE_PROXY);

        assertGe(
            subProxyUsdcStart,
            SUBPROXY_PSM_SWAP_USDC,
            "grove-proxy-insufficient-usdc-balance"
        );

        executeAllPayloadsAndBridges();

        assertEq(
            usdc.balanceOf(Ethereum.GROVE_PROXY),
            subProxyUsdcStart - SUBPROXY_PSM_SWAP_USDC,
            "grove-proxy-usdc-not-decreased"
        );

        // The corresponding SubProxy USDS inflow (+SUBPROXY_PSM_SWAP_USDC * 1e12 at the current 0 PSM fee)
        // is verified together with the treasury-distribution outflow in test_ETHEREUM_subProxyUsdsNetDelta().
    }

    function test_ETHEREUM_treasuryDistributionToGroveFoundation() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 foundationUsdsStart = usds.balanceOf(Ethereum.GROVE_FOUNDATION);

        assertGe(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            GROVE_FOUNDATION_USDS_GRANT,
            "grove-proxy-insufficient-usds-balance"
        );

        executeAllPayloadsAndBridges();

        assertEq(
            usds.balanceOf(Ethereum.GROVE_FOUNDATION),
            foundationUsdsStart + GROVE_FOUNDATION_USDS_GRANT,
            "foundation-usds-balance-not-increased"
        );
    }

    function test_ETHEREUM_subProxyUsdsNetDelta() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 subProxyUsdsStart = usds.balanceOf(Ethereum.GROVE_PROXY);

        executeAllPayloadsAndBridges();

        // The PSM swap moves +SUBPROXY_PSM_SWAP_USDC * 1e12 USDS into the SubProxy (USDC -> USDS via the Sky PSM, 0 fee).
        // The treasury distribution moves -GROVE_FOUNDATION_USDS_GRANT USDS out of the SubProxy (to the Grove Foundation).
        // The PAU / Basin actions move no USDS through the SubProxy.
        assertEq(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            subProxyUsdsStart + SUBPROXY_PSM_SWAP_USDC * 1e12 - GROVE_FOUNDATION_USDS_GRANT,
            "grove-proxy-usds-net-delta-mismatch"
        );
    }

}
