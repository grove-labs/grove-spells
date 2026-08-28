// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Vm } from "forge-std/Vm.sol";

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";

import { RecordedLogs } from "xchain-helpers/testing/utils/RecordedLogs.sol";

import { IRateLimits as IPauRateLimits } from "diamond-pau/interfaces/IRateLimits.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { IPauAccessControlsLike } from "src/test-harness/CommonPauTestBase.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface IBasinRolesLike {
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IMorphoVaultV2Like {
    function curator() external view returns (address);
    function isSentinel(address account) external view returns (bool);
    function owner() external view returns (address);
}

contract GroveEthereum_20260910_Test is GroveTestBase {

    // Must equal the addresses hardcoded in the 20260910 payload.
    address internal constant BUIDL_I_GROVE_BASIN                     = 0xf1615aC3181a4a28D35fB2b9cea84dd4a199B9D7;
    address internal constant CENTRIFUGE_OPERATOR_WALLET              = 0x7Bf090B97f896fB77e852CC98aa52A8Cb7DC02eC;
    address internal constant GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT = 0xbeef05061FE51eA482BD1b68041353490b3a5934;

    // Counterparty configuration this spell relies on and does not write to.
    address internal constant BUIDL_I_BASIN_ADMIN_TIMELOCK   = 0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34;
    address internal constant BUIDL_I_BASIN_DEPLOYER         = 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817;
    address internal constant BUIDL_I_ISSUER_REDEEMER        = 0x488F27168a19472c51f003fbC5b75B1ACc3B7b4c;
    address internal constant BUIDL_I_TOKEN_REDEEMER         = 0xECa0FF40a7C01629CE5E2425800D1D618F31C565;
    address internal constant JTRSY_ISSUER_REDEMPTION_WALLET = 0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a;
    address internal constant USDG                           = 0xe343167631d89B6Ffc58B88d6b7fB0228795491D;
    address internal constant USDG_VAULT_CURATOR             = 0x622E19d6903BD4507cfc70b31d5B99535114C0FC;

    // TODO: Pre-requirements 6 - Grove engineering appoints the vault's sentinel before execution.
    address internal constant USDG_VAULT_SENTINEL = address(0);

    // The August 27, 2026 spell: archived and deployed, but not cast as of this fork block.
    address internal constant PAYLOAD_20260827          = 0xF3d4F600640a87F4203DF0A554642228a119711e;
    bytes32 internal constant PAYLOAD_20260827_CODEHASH = 0x89f28b693c551c87c8dbd632484c39e8e5e1ac040696ed7839776ba3beae23c5;

    bytes32 internal constant DEFAULT_ADMIN_ROLE     = 0x00;
    bytes32 internal constant MANAGER_ADMIN_ROLE     = keccak256("MANAGER_ADMIN_ROLE");
    bytes32 internal constant MANAGER_ROLE           = keccak256("MANAGER_ROLE");
    bytes32 internal constant PAUSER_ROLE            = keccak256("PAUSER_ROLE");
    bytes32 internal constant REDEEMER_CONTRACT_ROLE = keccak256("REDEEMER_CONTRACT_ROLE");
    bytes32 internal constant REDEEMER_ROLE          = keccak256("REDEEMER_ROLE");

    bytes32 internal constant ROLE_GRANTED = keccak256("RoleGranted(bytes32,address,address)");
    bytes32 internal constant ROLE_REVOKED = keccak256("RoleRevoked(bytes32,address,address)");

    constructor() {
        id = "20260910";
    }

    function setUp() public {
        setupDomains("2026-08-28T16:30:30Z");

        _executePreviousSpell20260827();

        deployPayloads();
    }

    function _executePreviousSpell20260827() internal {
        // Fails once the fork block moves past the real cast, when this call must be deleted instead.
        assertFalse(
            IPauAccessControlsLike(Ethereum.PAU_ACCESS_CONTROLS).hasRole(DEFAULT_ADMIN_ROLE, Ethereum.PAS_CONFIGURATOR),
            "previous-spell-already-executed"
        );

        _executePreviousSpell(PAYLOAD_20260827, PAYLOAD_20260827_CODEHASH);
    }

    function test_ETHEREUM_previousSpellExecutedInSetup() public onChain(ChainIdUtils.Ethereum()) {
        // Nothing else here depends on the previous spell, so a no-op setUp would go unnoticed.
        assertTrue(
            IPauAccessControlsLike(Ethereum.PAU_ACCESS_CONTROLS).hasRole(DEFAULT_ADMIN_ROLE, Ethereum.PAS_CONFIGURATOR),
            "previous-spell-not-executed-in-setup"
        );
    }

    function test_ETHEREUM_onboardBuidlIBasin() public onChain(ChainIdUtils.Ethereum()) {
        _testBasinOnboarding({
            basin                 : BUIDL_I_GROVE_BASIN,
            swapToken             : Ethereum.USDS,
            collateralToken       : Ethereum.USDC,
            expectedDepositAmount : 1_000_000e18,
            depositMax            : 5_000_000e18,
            depositSlope          : 5_000_000e18 / uint256(1 days)
        });
    }

    function test_ETHEREUM_buidlIBasinMatchesBuidlBasinPhase() public onChain(ChainIdUtils.Ethereum()) {
        // Post-checks 1: both Instances share a ramp-up phase, so they match rather than hold a figure.
        IPauRateLimits rateLimits = IPauRateLimits(Ethereum.PAU_RATE_LIMITS);

        executeAllPayloadsAndBridges();

        IPauRateLimits.RateLimitData memory buidlI = rateLimits.getRateLimitData(_basinDepositKey(BUIDL_I_GROVE_BASIN, Ethereum.USDS));
        IPauRateLimits.RateLimitData memory buidl  = rateLimits.getRateLimitData(_basinDepositKey(Ethereum.BUIDL_GROVE_BASIN, Ethereum.USDS));

        assertEq(buidlI.maxAmount, buidl.maxAmount, "buidl-i-max-amount-not-matching-buidl");
        assertEq(buidlI.slope,     buidl.slope,     "buidl-i-slope-not-matching-buidl");
    }

    function test_ETHEREUM_existingBasinRateLimitsUnchanged() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        _assertPauRateLimit(_basinDepositKey(Ethereum.JTRSY_GROVE_BASIN, Ethereum.USDS), 5_000_000e18, 5_000_000e18 / uint256(1 days));
        _assertPauRateLimit(_basinDepositKey(Ethereum.BUIDL_GROVE_BASIN, Ethereum.USDS), 5_000_000e18, 5_000_000e18 / uint256(1 days));

        _assertPauUnlimitedRateLimit(_basinWithdrawKey(Ethereum.JTRSY_GROVE_BASIN, Ethereum.USDS));
        _assertPauUnlimitedRateLimit(_basinWithdrawKey(Ethereum.JTRSY_GROVE_BASIN, Ethereum.USDC));
        _assertPauUnlimitedRateLimit(_basinWithdrawKey(Ethereum.BUIDL_GROVE_BASIN, Ethereum.USDS));
        _assertPauUnlimitedRateLimit(_basinWithdrawKey(Ethereum.BUIDL_GROVE_BASIN, Ethereum.USDC));
    }

    function test_ETHEREUM_buidlIBasinRoleConfiguration() public onChain(ChainIdUtils.Ethereum()) {
        IBasinRolesLike basin = IBasinRolesLike(BUIDL_I_GROVE_BASIN);

        assertTrue(basin.hasRole(DEFAULT_ADMIN_ROLE,     BUIDL_I_BASIN_ADMIN_TIMELOCK), "admin-timelock-not-default-admin");
        assertTrue(basin.hasRole(MANAGER_ROLE,           Ethereum.ALM_RELAYER),         "relayer-not-manager");
        assertTrue(basin.hasRole(PAUSER_ROLE,            Ethereum.ALM_FREEZER),         "freezer-not-pauser");
        assertTrue(basin.hasRole(REDEEMER_ROLE,          BUIDL_I_ISSUER_REDEEMER),      "issuer-redeemer-not-redeemer");
        assertTrue(basin.hasRole(REDEEMER_CONTRACT_ROLE, BUIDL_I_TOKEN_REDEEMER),       "token-redeemer-not-redeemer-contract");
        assertTrue(basin.hasRole(MANAGER_ADMIN_ROLE,     Ethereum.GROVE_PROXY),         "sub-proxy-not-manager-admin");

        assertFalse(basin.hasRole(DEFAULT_ADMIN_ROLE, BUIDL_I_BASIN_DEPLOYER), "deployer-still-default-admin");
        assertFalse(basin.hasRole(PAUSER_ROLE,        BUIDL_I_BASIN_DEPLOYER), "deployer-still-pauser");
    }

    function test_ETHEREUM_buidlIBasinDeployerPrivilegeReleased() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Pre-requirements 1 - the Basin lead revokes the deployer's MANAGER_ADMIN_ROLE before
        //       execution; drop this skip then. The rest of the role set is covered by the test above.
        vm.skip(true);

        IBasinRolesLike basin = IBasinRolesLike(BUIDL_I_GROVE_BASIN);

        assertFalse(basin.hasRole(MANAGER_ADMIN_ROLE, BUIDL_I_BASIN_DEPLOYER), "deployer-still-manager-admin");
        assertTrue(basin.hasRole(MANAGER_ADMIN_ROLE, Ethereum.GROVE_PROXY),    "sub-proxy-not-manager-admin");
    }

    function test_ETHEREUM_grantJtrsyBasinRedeemerRole() public onChain(ChainIdUtils.Ethereum()) {
        IBasinRolesLike basin = IBasinRolesLike(Ethereum.JTRSY_GROVE_BASIN);

        // The grant needs no TimelockController route because the SubProxy administers REDEEMER_ROLE.
        assertEq(basin.getRoleAdmin(REDEEMER_ROLE), MANAGER_ADMIN_ROLE, "redeemer-role-admin-not-manager-admin");
        assertTrue(basin.hasRole(MANAGER_ADMIN_ROLE, Ethereum.GROVE_PROXY), "sub-proxy-not-manager-admin");

        assertFalse(basin.hasRole(REDEEMER_ROLE, CENTRIFUGE_OPERATOR_WALLET),    "grantee-already-redeemer");
        assertTrue(basin.hasRole(REDEEMER_ROLE, JTRSY_ISSUER_REDEMPTION_WALLET), "issuer-wallet-not-redeemer");

        executeAllPayloadsAndBridges();

        assertTrue(basin.hasRole(REDEEMER_ROLE, CENTRIFUGE_OPERATOR_WALLET),     "grantee-not-redeemer");
        assertTrue(basin.hasRole(REDEEMER_ROLE, JTRSY_ISSUER_REDEMPTION_WALLET), "issuer-wallet-lost-redeemer");
    }

    function test_ETHEREUM_jtrsyBasinRoleSetOtherwiseUnchanged() public onChain(ChainIdUtils.Ethereum()) {
        // The bridge helpers drain vm.getRecordedLogs(), so read through the same accumulator they use.
        // Everything recorded so far is setup and must not be counted.
        uint256 logsBefore = RecordedLogs.getLogs().length;

        executeAllPayloadsAndBridges();

        Vm.Log[] memory logs = RecordedLogs.getLogs();

        uint256 granted;

        for (uint256 i = logsBefore; i < logs.length; ++i) {
            if (logs[i].emitter != Ethereum.JTRSY_GROVE_BASIN) continue;

            if (logs[i].topics.length == 0) continue;

            assertTrue(logs[i].topics[0] != ROLE_REVOKED, "unexpected-role-revoked");

            if (logs[i].topics[0] != ROLE_GRANTED) continue;

            assertEq(logs[i].topics[1], REDEEMER_ROLE, "unexpected-role-granted");

            assertEq(
                address(uint160(uint256(logs[i].topics[2]))),
                CENTRIFUGE_OPERATOR_WALLET,
                "unexpected-role-grantee"
            );

            ++granted;
        }

        assertEq(granted, 1, "unexpected-role-granted-count");
    }

    function test_ETHEREUM_onboardGroveXSteakhouseUsdgMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : 50_000_000e6,
            depositSlope          : 50_000_000e6 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 2e6
        });
    }

    function test_ETHEREUM_usdgVaultWiringAndCeilingMatchesUsdcTwin() public onChain(ChainIdUtils.Ethereum()) {
        // shareUnit / maxAssetsPerShare are only correct for an 18-decimal share on a 6-decimal asset.
        assertEq(IERC4626(GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT).asset(),    USDG, "vault-asset-not-usdg");
        assertEq(IERC4626(GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT).decimals(), 18,   "vault-decimals-not-18");
        assertEq(IERC20(USDG).decimals(),                                      6,    "usdg-decimals-not-6");

        executeAllPayloadsAndBridges();

        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        assertEq(
            controller.maxExchangeRates(GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT),
            controller.maxExchangeRates(Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT),
            "usdg-ceiling-not-matching-usdc-twin"
        );
    }

    function test_ETHEREUM_usdgVaultRoleConfiguration() public onChain(ChainIdUtils.Ethereum()) {
        IMorphoVaultV2Like vault = IMorphoVaultV2Like(GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT);

        assertEq(vault.owner(),   Ethereum.GROVE_PROXY, "vault-owner-not-grove-sub-proxy");
        assertEq(vault.curator(), USDG_VAULT_CURATOR,   "vault-curator-not-expected-safe");
    }

    function test_ETHEREUM_usdgVaultSentinelAppointed() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Pre-requirements 6 - Grove engineering appoints the sentinel before execution. Filling
        //       USDG_VAULT_SENTINEL in activates this; the spell's own calls do not depend on it.
        vm.skip(USDG_VAULT_SENTINEL == address(0));

        assertTrue(
            IMorphoVaultV2Like(GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT).isSentinel(USDG_VAULT_SENTINEL),
            "vault-sentinel-not-appointed"
        );
    }

}
