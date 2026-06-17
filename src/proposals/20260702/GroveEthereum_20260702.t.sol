// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

import {
    IPAUBaseControllerLike,
    IPAUProxyLike,
    IPAUAccessControlsLike,
    IPAURateLimitsLike,
    PAUContext
} from "src/test-harness/CommonPAUTestBase.sol";

// --- Maker core (for simulating Sky's not-yet-executed ALLOCATOR-GROVE-A ilk init) ---

interface IVatLike {
    function ilks(bytes32 ilk) external view returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
    function init(bytes32 ilk) external;
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function slip(bytes32 ilk, address usr, int256 wad) external;
    function grab(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external;
}

interface IJugLike {
    function ilks(bytes32 ilk) external view returns (uint256 duty, uint256 rho);
    function init(bytes32 ilk) external;
}

interface IDssAutoLineLike {
    function setIlk(bytes32 ilk, uint256 line, uint256 gap, uint256 ttl) external;
    function exec(bytes32 ilk) external returns (uint256);
}

// --- Sky allocator instance (dss-allocator) ---

interface IAllocatorVaultLike {
    function file(bytes32 what, address data) external;
    function wards(address usr) external view returns (uint256);
    function buffer() external view returns (address);
}

interface IAllocatorBufferLike {
    function approve(address asset, address spender, uint256 amount) external;
    function wards(address usr) external view returns (uint256);
}

// --- New Diamond PAU (DPAU) controller facets ---

interface IPAUControllerLike is IPAUBaseControllerLike {
    function basin_deposit(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external returns (uint256 shares);
}

interface IDpauAccessControlsLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
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

    // New Diamond PAU (DPAU) system, onboarded in parallel to the legacy ALM system.
    address internal constant DPAU_PROXY                      = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;
    address internal constant DPAU_CONTROLLER                 = 0xbf83F5974B932c7D842254042717D6A2706CE5eE;
    address internal constant DPAU_ACCESS_CONTROLS            = 0x4F6d1704700cd494DD4cd9bF59c0C39DA1Bc9164;
    address internal constant DPAU_RATE_LIMITS                = 0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1;
    address internal constant DPAU_ADMINISTERED_AGENT         = 0xdBD17832df0e57b1732cE1C84c652E820e549BAa;
    address internal constant DPAU_BEACON                     = 0x829dC2b7E94B1954F0764E573f2E0d45Afa28199;
    address internal constant DPAU_FACTORY                    = 0x69A5d548830AC2A4Ba90A44a2C75BDA71f97fc66;
    address internal constant DPAU_ADMINISTERED_AGENT_FACTORY = 0x2968c3b5478cF93B70aB1e24255d4EDBBd27a089;
    address internal constant DPAU_DEFAULT_ASSEMBLER          = 0xc812aAD3FaE2D3511C664374B601a9BeBFeCCa2E;
    address internal constant DPAU_BASIN_FACET                = 0xC84825BCD13AEddc372400239499380376a44A39;
    address internal constant DPAU_PSM_FACET                  = 0xE4A5dAc768a310cc2316f258901b32E499653064;
    address internal constant DPAU_USDS_FACET                 = 0x1221CC4B85Ab260660aD21C2829e0EB516dffBc7;

    // New Sky ALLOCATOR-GROVE-A instance (deployed by Sky's 2026-06-18 spell).
    address internal constant ALLOCATOR_GROVE_A_VAULT  = 0xf739a30c74927dc6cFA3B67E4933872a1FC5F4EB;
    address internal constant ALLOCATOR_GROVE_A_BUFFER = 0x436DABce608f73BeA2b75fba35bffe72739697d5;

    // MCD_JUG is not in grove-address-registry (Sky: MCD Jug on Etherscan).
    address internal constant MCD_JUG = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;

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
        setupDomains("2026-06-15T18:00:00Z");
        deployPayloads();

        _setPAUContext(
            ChainIdUtils.Ethereum(),
            PAUContext({
                controller     : DPAU_CONTROLLER,
                proxy          : IPAUProxyLike(DPAU_PROXY),
                accessControls : IPAUAccessControlsLike(DPAU_ACCESS_CONTROLS),
                rateLimits     : IPAURateLimitsLike(DPAU_RATE_LIMITS),
                agent          : DPAU_ADMINISTERED_AGENT,
                actor          : Ethereum.ALM_RELAYER
            })
        );

        // The DPAU system mints USDS through Sky's ALLOCATOR-GROVE-A instance, whose
        // ilk init runs in Sky's 2026-06-18 spell (after this 2026-06-15 fork). Simulate
        // that init (and the DPAU proxy's PSM whitelisting) so the spell's allocator hookup
        // and the operational mint/swap tests work.
        _simulateAllocatorGroveAInit();
    }

    function test_ETHEREUM_dpauSystemPreconfiguration() public onChain(ChainIdUtils.Ethereum()) {
        IPAUControllerLike      controller     = IPAUControllerLike(DPAU_CONTROLLER);
        IDpauAccessControlsLike accessControls = IDpauAccessControlsLike(DPAU_ACCESS_CONTROLS);
        IAdministeredAgentMembersLike agent    = IAdministeredAgentMembersLike(DPAU_ADMINISTERED_AGENT);

        // Deployments exist
        assertGt(DPAU_CONTROLLER.code.length,                 0, "controller-not-deployed");
        assertGt(DPAU_PROXY.code.length,                      0, "proxy-not-deployed");
        assertGt(DPAU_ACCESS_CONTROLS.code.length,            0, "access-controls-not-deployed");
        assertGt(DPAU_RATE_LIMITS.code.length,                0, "rate-limits-not-deployed");
        assertGt(DPAU_ADMINISTERED_AGENT.code.length,         0, "administered-agent-not-deployed");
        assertGt(DPAU_ADMINISTERED_AGENT_FACTORY.code.length, 0, "administered-agent-factory-not-deployed");
        assertGt(DPAU_DEFAULT_ASSEMBLER.code.length,          0, "default-assembler-not-deployed");
        assertGt(DPAU_BASIN_FACET.code.length,                0, "basin-facet-not-deployed");
        assertGt(DPAU_PSM_FACET.code.length,                  0, "psm-facet-not-deployed");
        assertGt(DPAU_USDS_FACET.code.length,                 0, "usds-facet-not-deployed");

        // Controller wiring (now points at the new DPAU proxy / rate limits, not the legacy ALM system)
        assertEq(controller.accessControls(), DPAU_ACCESS_CONTROLS, "controller-access-controls-mismatch");
        assertEq(controller.beacon(),         DPAU_BEACON,          "controller-beacon-mismatch");
        assertEq(controller.proxy(),          DPAU_PROXY,           "controller-proxy-mismatch");
        assertEq(controller.rateLimits(),     DPAU_RATE_LIMITS,     "controller-rate-limits-mismatch");

        // The DPAU factory grants the controller the CONTROLLER role on its own proxy + rate limits
        // at deployment, so the payload does not need to; the mint/swap/basin tests confirm it stays
        // operational after the spell.
        assertTrue(IPAUProxyLike(DPAU_PROXY).hasRole(CONTROLLER, DPAU_CONTROLLER),            "controller-missing-proxy-role");
        assertTrue(IPAURateLimitsLike(DPAU_RATE_LIMITS).hasRole(CONTROLLER, DPAU_CONTROLLER), "controller-missing-rate-limits-role");

        // Facet dispatch wiring
        assertEq(controller.getDispatch(IPAUControllerLike.basin_deposit.selector).facet,    DPAU_BASIN_FACET, "basin-facet-not-wired");
        assertEq(controller.getDispatch(IPAUBaseControllerLike.usds_mint.selector).facet,         DPAU_USDS_FACET,  "usds-facet-not-wired");
        assertEq(controller.getDispatch(IPAUBaseControllerLike.psm_swapUSDSToUSDC.selector).facet, DPAU_PSM_FACET,  "psm-facet-not-wired");

        // Access controls: the Grove SubProxy is the sole admin; the agent is an allocator
        assertTrue(accessControls.hasRole(DEFAULT_ADMIN_ROLE, Ethereum.GROVE_PROXY), "subproxy-missing-admin-role");
        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1,           "admin-role-member-count");
        assertFalse(accessControls.hasRole(DEFAULT_ADMIN_ROLE, DPAU_FACTORY),        "factory-still-admin");
        assertTrue(accessControls.hasRole(ALLOCATOR_ROLE, DPAU_ADMINISTERED_AGENT),  "agent-missing-allocator-role");

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

    function test_ETHEREUM_initDpauSystem() public onChain(ChainIdUtils.Ethereum()) {
        IAllocatorVaultLike vault      = IAllocatorVaultLike(ALLOCATOR_GROVE_A_VAULT);
        IERC20              usds       = IERC20(Ethereum.USDS);
        IPAUControllerLike controller = IPAUControllerLike(DPAU_CONTROLLER);

        assertEq(vault.buffer(),          ALLOCATOR_GROVE_A_BUFFER, "vault-buffer-mismatch");
        assertEq(controller.usds_vault(), address(0),               "controller-already-has-vault");

        assertEq(vault.wards(DPAU_PROXY),                              0, "proxy-already-vault-ward");
        assertEq(usds.allowance(ALLOCATOR_GROVE_A_BUFFER, DPAU_PROXY), 0, "proxy-already-has-buffer-allowance");

        executeAllPayloadsAndBridges();

        assertEq(vault.buffer(),          ALLOCATOR_GROVE_A_BUFFER, "vault-buffer-mismatch");
        assertEq(controller.usds_vault(), ALLOCATOR_GROVE_A_VAULT,  "controller-vault-not-set");

        assertEq(vault.wards(DPAU_PROXY),                              1,                 "proxy-not-vault-ward");
        assertEq(usds.allowance(ALLOCATOR_GROVE_A_BUFFER, DPAU_PROXY), type(uint256).max, "proxy-missing-buffer-allowance");
    }

    function test_ETHEREUM_onboardUsdsMintBurnToDpau() public onChain(ChainIdUtils.Ethereum()) {
        IPAUControllerLike controller = IPAUControllerLike(DPAU_CONTROLLER);

        bytes32 mintKey = controller.usds_mintRateLimitKey();
        bytes32 burnKey = controller.usds_burnRateLimitKey();

        // --- Before: mint + burn limits unset. ---
        _assertPAUZeroRateLimit(mintKey);
        _assertPAUZeroRateLimit(burnKey);

        executeAllPayloadsAndBridges();

        // --- After: mint + burn limits set to the onboarded values. ---
        _assertPAURateLimit(mintKey, USDS_MINT_MAX, USDS_MINT_SLOPE);
        _assertPAURateLimit(burnKey, USDS_BURN_MAX, USDS_BURN_SLOPE);

        // --- Operational: mint USDS through ALLOCATOR-GROVE-A, then burn it back. ---
        PAUContext memory ctx  = _getPAUContext();
        IERC20            usds = IERC20(Ethereum.USDS);

        uint256 proxyUsdsStart = usds.balanceOf(address(ctx.proxy));
        uint256 amount         = 1_000_000e18;

        assertEq(ctx.rateLimits.getCurrentRateLimit(mintKey), USDS_MINT_MAX, "mint-rate-limit-not-full");
        assertEq(ctx.rateLimits.getCurrentRateLimit(burnKey), USDS_BURN_MAX, "burn-rate-limit-not-full");

        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.usds_mint, (amount)));

        assertEq(usds.balanceOf(address(ctx.proxy)),          proxyUsdsStart + amount, "proxy-usds-not-minted");
        assertEq(ctx.rateLimits.getCurrentRateLimit(mintKey), USDS_MINT_MAX - amount,  "mint-rate-limit-not-decreased");

        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.usds_burn, (amount)));

        assertEq(usds.balanceOf(address(ctx.proxy)),          proxyUsdsStart,         "proxy-usds-not-burned");
        assertEq(ctx.rateLimits.getCurrentRateLimit(burnKey), USDS_BURN_MAX - amount, "burn-rate-limit-not-decreased");
    }

    function test_ETHEREUM_onboardPsmSwapToDpau() public onChain(ChainIdUtils.Ethereum()) {
        IPAUControllerLike controller = IPAUControllerLike(DPAU_CONTROLLER);

        bytes32 usdsToUsdcKey = controller.psm_usdsToUSDCSwapRateLimitKey();
        bytes32 usdcToUsdsKey = controller.psm_usdcToUSDSSwapRateLimitKey();

        // --- Before: both swap limits unset. ---
        _assertPAUZeroRateLimit(usdsToUsdcKey);
        _assertPAUZeroRateLimit(usdcToUsdsKey);

        executeAllPayloadsAndBridges();

        // --- After: both swap limits set to the onboarded values. ---
        _assertPAURateLimit(usdsToUsdcKey, USDS_TO_USDC_MAX, USDS_TO_USDC_SLOPE);
        _assertPAURateLimit(usdcToUsdsKey, USDC_TO_USDS_MAX, USDC_TO_USDS_SLOPE);

        // --- Operational: mint USDS, swap it to USDC and back through the PSM, then burn it. ---
        PAUContext memory ctx  = _getPAUContext();
        IERC20            usds = IERC20(Ethereum.USDS);
        IERC20            usdc = IERC20(Ethereum.USDC);

        uint256 proxyUsdsStart = usds.balanceOf(address(ctx.proxy));
        uint256 proxyUsdcStart = usdc.balanceOf(address(ctx.proxy));
        uint256 swapUsdc       = 1_000_000e6;      // 1M USDC
        uint256 swapUsds       = swapUsdc * 1e12;  // 1M USDS equivalent (0 PSM fee)

        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.usds_mint, (swapUsds)));

        assertEq(usds.balanceOf(address(ctx.proxy)), proxyUsdsStart + swapUsds, "proxy-usds-not-minted");
        assertEq(usdc.balanceOf(address(ctx.proxy)), proxyUsdcStart,            "proxy-usdc-changed-by-mint");

        // Forward: USDS -> USDC (decreases the usds-to-usdc limit).
        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.psm_swapUSDSToUSDC, (swapUsdc)));

        assertEq(usds.balanceOf(address(ctx.proxy)), proxyUsdsStart,            "proxy-usds-not-spent");
        assertEq(usdc.balanceOf(address(ctx.proxy)), proxyUsdcStart + swapUsdc, "proxy-usdc-not-received");
        assertEq(ctx.rateLimits.getCurrentRateLimit(usdsToUsdcKey), USDS_TO_USDC_MAX - swapUsdc, "usds-to-usdc-limit-not-decreased");
        assertEq(ctx.rateLimits.getCurrentRateLimit(usdcToUsdsKey), USDC_TO_USDS_MAX,            "usdc-to-usds-limit-changed-on-forward");

        // Reverse: USDC -> USDS (refills the usds-to-usdc limit, decreases the usdc-to-usds limit).
        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.psm_swapUSDCToUSDS, (swapUsdc)));

        assertEq(usdc.balanceOf(address(ctx.proxy)), proxyUsdcStart,            "proxy-usdc-not-spent");
        assertEq(usds.balanceOf(address(ctx.proxy)), proxyUsdsStart + swapUsds, "proxy-usds-not-returned");
        assertEq(ctx.rateLimits.getCurrentRateLimit(usdsToUsdcKey), USDS_TO_USDC_MAX,            "usds-to-usdc-limit-not-refilled");
        assertEq(ctx.rateLimits.getCurrentRateLimit(usdcToUsdsKey), USDC_TO_USDS_MAX - swapUsdc, "usdc-to-usds-limit-not-decreased");

        // Burn the round-tripped USDS, closing out the position.
        _callAsPAUActor(ctx, abi.encodeCall(IPAUBaseControllerLike.usds_burn, (swapUsds)));

        assertEq(usds.balanceOf(address(ctx.proxy)), proxyUsdsStart, "proxy-usds-not-burned");
    }

    function test_ETHEREUM_onboardJtrsyBasin() public onChain(ChainIdUtils.Ethereum()) {
        _testBasinOnboarding(
            JTRSY_GROVE_BASIN,
            Ethereum.USDS,
            Ethereum.USDC,
            BASIN_DEPOSIT_TEST_AMOUNT,
            JTRSY_BASIN_DEPOSIT_MAX,
            JTRSY_BASIN_DEPOSIT_SLOPE
        );
    }

    function test_ETHEREUM_onboardBuidlBasin() public onChain(ChainIdUtils.Ethereum()) {
        _testBasinOnboarding(
            BUIDL_GROVE_BASIN,
            Ethereum.USDS,
            Ethereum.USDC,
            BASIN_DEPOSIT_TEST_AMOUNT,
            BUIDL_BASIN_DEPOSIT_MAX,
            BUIDL_BASIN_DEPOSIT_SLOPE
        );
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
        // The DPAU / Basin actions move no USDS through the SubProxy.
        assertEq(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            subProxyUsdsStart + SUBPROXY_PSM_SWAP_USDC * 1e12 - GROVE_FOUNDATION_USDS_GRANT,
            "grove-proxy-usds-net-delta-mismatch"
        );
    }

    // --- helpers ---

    /// @dev Replays the vat/jug ilk wiring + vault/buffer ownership that Sky's
    ///      2026-06-18 spell performs for ALLOCATOR-GROVE-A, so the DPAU system can
    ///      draw USDS through the vault at this earlier fork. Mirrors AllocatorInit.initIlk.
    function _simulateAllocatorGroveAInit() private {
        if (ChainIdUtils.fromUint(block.chainid) != ChainIdUtils.Ethereum()) return;

        uint256 RAY = 1e27;
        uint256 RAD = 1e45;

        uint256 ink  = 1_000_000_000_000 ether;  // locked collateral so the debt ceiling (not collateral) binds

        bytes32 ilk = GROVE_PAU_ALLOCATOR_ILK;

        IVatLike         vat      = IVatLike(Ethereum.VAT);
        IJugLike         jug      = IJugLike(MCD_JUG);
        IDssAutoLineLike autoLine = IDssAutoLineLike(Ethereum.AUTO_LINE);

        // (1) Wire the ilk into the Maker core as the Maker PauseProxy would.
        vm.startPrank(Ethereum.PAUSE_PROXY);
        ( , uint256 rate, , , ) = vat.ilks(ilk);
        if (rate == 0) vat.init(ilk);
        vat.file(ilk, "spot", RAY);
        // Onboard the ilk debt ceiling via the real DC-IAM (autoline) with the production
        // ALLOCATOR-GROVE-A params: maxLine 5M, gap 1M, ttl 1 day, duty 0 (rate-limit-values.md).
        autoLine.setIlk(ilk, 5_000_000 * RAD, 1_000_000 * RAD, 1 days);
        vat.slip(ilk, ALLOCATOR_GROVE_A_VAULT, int256(ink));
        vat.grab(ilk, ALLOCATOR_GROVE_A_VAULT, ALLOCATOR_GROVE_A_VAULT, address(0), int256(ink), 0);

        ( uint256 duty, ) = jug.ilks(ilk);
        if (duty == 0) jug.init(ilk);  // jug.init sets duty = RAY, i.e. a 0% stability fee
        vm.stopPrank();

        // exec() ramps the vat ilk line to the initial gap (1M) and bumps the global Line, as Sky's spell would.
        autoLine.exec(ilk);

        // (2) Hand vault + buffer ownership to the Grove SubProxy (Sky's switchOwner step).
        //     Forced via storage because the pre-init ward is the Sky deployer (wards is slot 0).
        vm.store(ALLOCATOR_GROVE_A_VAULT,  keccak256(abi.encode(Ethereum.GROVE_PROXY, uint256(0))), bytes32(uint256(1)));
        vm.store(ALLOCATOR_GROVE_A_BUFFER, keccak256(abi.encode(Ethereum.GROVE_PROXY, uint256(0))), bytes32(uint256(1)));

        // (3) Point the vault at the jug and let the vault pull USDS from the buffer (for wipe).
        vm.startPrank(Ethereum.GROVE_PROXY);
        IAllocatorVaultLike(ALLOCATOR_GROVE_A_VAULT).file("jug", MCD_JUG);
        IAllocatorBufferLike(ALLOCATOR_GROVE_A_BUFFER).approve(Ethereum.USDS, ALLOCATOR_GROVE_A_VAULT, type(uint256).max);
        vm.stopPrank();

        // (4) Whitelist the DPAU proxy on the Sky Lite PSM's no-fee buyGem/sellGem path (`bud`),
        //     as the old ALM proxy already is, so the PSM swaps are operational. Sky kisses it
        //     separately, so replay that kiss here.
        vm.prank(Ethereum.PAUSE_PROXY);
        ILitePsmLike(Ethereum.PSM).kiss(DPAU_PROXY);
    }

}
