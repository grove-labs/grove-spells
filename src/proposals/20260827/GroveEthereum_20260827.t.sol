// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Vm }     from "forge-std/Vm.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { RecordedLogs } from "xchain-helpers/testing/utils/RecordedLogs.sol";

import { IAccessControls }                       from "diamond-pau/interfaces/IAccessControls.sol";
import { IRateLimits as IPauRateLimits }         from "diamond-pau/interfaces/IRateLimits.sol";
import { makeAddressKey, makeAddressAddressKey } from "diamond-pau/libraries/RateLimitHelpers.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase }   from "src/test-harness/GroveTestBase.sol";
import { IStarGuardLike }  from "src/test-harness/SpellRunner.sol";

contract GroveEthereum_20260827_Test is GroveTestBase {

    // August 13, 2026 spell, deployed 2026-08-07 and cast after this spell's fork block.
    // Codehash per archive/20260813/20260813.md.
    address internal constant PAYLOAD_20260813          = 0xb12C687188427d7D1E5253afA5f09A101Fbd9d4b;
    bytes32 internal constant PAYLOAD_20260813_CODEHASH = 0x180fc2de506150de525027a135843e91123578dc1f03945b69a489dce863f85c;

    bytes32 internal constant LIMIT_UNISWAP_V3_DEPOSIT  = keccak256("LIMIT_UNISWAP_V3_DEPOSIT");
    bytes32 internal constant LIMIT_UNISWAP_V3_SWAP     = keccak256("LIMIT_UNISWAP_V3_SWAP");
    bytes32 internal constant LIMIT_UNISWAP_V3_WITHDRAW = keccak256("LIMIT_UNISWAP_V3_WITHDRAW");

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 internal constant ROLE_GRANTED = keccak256("RoleGranted(bytes32,address,address)");
    bytes32 internal constant ROLE_REVOKED = keccak256("RoleRevoked(bytes32,address,address)");

    // Must equal PAS_CONFIGURATOR in the 20260827 payload.
    address internal constant PAS_CONFIGURATOR = 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929;

    constructor() {
        id = "20260827";
    }

    function setUp() public {
        setupDomains("2026-08-13T15:56:36Z");

        _executePreviousSpell();

        deployPayloads();
    }

    /// @dev Item 2 edits three rate-limit keys the August 13, 2026 spell creates, and that spell had
    /// not been cast at this fork block. Execute it here so every test runs against the state this
    /// spell will actually land on. Mirrors SpellRunner.executeMainnetPayload.
    function _executePreviousSpell() internal {
        // Obsolescence guard: fails the day the fork block moves past the real cast, at which point this
        // helper must be deleted rather than left to re-execute the payload on top of itself.
        _assertPauZeroRateLimit(makeAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.UNISWAP_V3_AUSD_USDC));

        assertEq(PAYLOAD_20260813.codehash, PAYLOAD_20260813_CODEHASH, "previous-spell-codehash-mismatch");

        vm.prank(Ethereum.PAUSE_PROXY);
        IStarGuardLike(Ethereum.GROVE_STAR_GUARD).plot({
            addr_ : PAYLOAD_20260813,
            tag_  : PAYLOAD_20260813_CODEHASH
        });

        assertEq(
            IStarGuardLike(Ethereum.GROVE_STAR_GUARD).exec(),
            PAYLOAD_20260813,
            "previous-spell-not-executed"
        );
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

    function test_ETHEREUM_raiseUniswapV3DepositRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 aggregateDepositKey = makeAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 ausdDepositKey      = makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcDepositKey      = makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);

        // Initial ramp-up values written by the August 13, 2026 spell, executed in setUp: the maximum
        // with a zero slope, so the allowance does not replenish.
        _assertPauRateLimit(aggregateDepositKey, 5_000_000e18, 0);
        _assertPauRateLimit(ausdDepositKey,      5_000_000e6,  0);
        _assertPauRateLimit(usdcDepositKey,      5_000_000e6,  0);

        executeAllPayloadsAndBridges();

        _assertPauRateLimit(aggregateDepositKey, 5_000_000e18, 350_000e18 / uint256(1 days));
        _assertPauRateLimit(ausdDepositKey,      5_000_000e6,  350_000e6  / uint256(1 days));
        _assertPauRateLimit(usdcDepositKey,      5_000_000e6,  350_000e6  / uint256(1 days));
    }

    function test_ETHEREUM_uniswapV3NonDepositRateLimitsUnchanged() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 aggregateWithdrawKey = makeAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 ausdWithdrawKey      = makeAddressAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcWithdrawKey      = makeAddressAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 ausdSwapKey          = makeAddressAddressKey(LIMIT_UNISWAP_V3_SWAP,     Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcSwapKey          = makeAddressAddressKey(LIMIT_UNISWAP_V3_SWAP,     Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);

        executeAllPayloadsAndBridges();

        _assertPauUnlimitedRateLimit(aggregateWithdrawKey);
        _assertPauUnlimitedRateLimit(ausdWithdrawKey);
        _assertPauUnlimitedRateLimit(usdcWithdrawKey);

        _assertPauRateLimit(ausdSwapKey, 1_000_000e6, 5_000_000e6 / uint256(1 days));
        _assertPauRateLimit(usdcSwapKey, 1_000_000e6, 5_000_000e6 / uint256(1 days));
    }

    function test_ETHEREUM_authorizePasConfigurator() public onChain(ChainIdUtils.Ethereum()) {
        IAccessControls accessControls = IAccessControls(Ethereum.PAU_ACCESS_CONTROLS);
        IPauRateLimits  rateLimits     = IPauRateLimits(Ethereum.PAU_RATE_LIMITS);

        // Pre-requirements 3: granting the role to an undeployed address would succeed silently.
        assertGt(PAS_CONFIGURATOR.code.length, 0, "configurator-not-deployed");

        assertFalse(accessControls.hasRole(DEFAULT_ADMIN_ROLE, PAS_CONFIGURATOR), "configurator-already-access-controls-admin");
        assertFalse(rateLimits.hasRole(DEFAULT_ADMIN_ROLE,     PAS_CONFIGURATOR), "configurator-already-rate-limits-admin");

        executeAllPayloadsAndBridges();

        assertTrue(accessControls.hasRole(DEFAULT_ADMIN_ROLE, PAS_CONFIGURATOR), "configurator-not-access-controls-admin");
        assertTrue(rateLimits.hasRole(DEFAULT_ADMIN_ROLE,     PAS_CONFIGURATOR), "configurator-not-rate-limits-admin");
    }

    function test_ETHEREUM_groveSubProxyRetainsPauAdminRole() public onChain(ChainIdUtils.Ethereum()) {
        IAccessControls accessControls = IAccessControls(Ethereum.PAU_ACCESS_CONTROLS);
        IPauRateLimits  rateLimits     = IPauRateLimits(Ethereum.PAU_RATE_LIMITS);

        assertTrue(accessControls.hasRole(DEFAULT_ADMIN_ROLE, Ethereum.GROVE_PROXY), "sub-proxy-not-access-controls-admin");
        assertTrue(rateLimits.hasRole(DEFAULT_ADMIN_ROLE,     Ethereum.GROVE_PROXY), "sub-proxy-not-rate-limits-admin");

        executeAllPayloadsAndBridges();

        assertTrue(accessControls.hasRole(DEFAULT_ADMIN_ROLE, Ethereum.GROVE_PROXY), "sub-proxy-lost-access-controls-admin");
        assertTrue(rateLimits.hasRole(DEFAULT_ADMIN_ROLE,     Ethereum.GROVE_PROXY), "sub-proxy-lost-rate-limits-admin");
    }

    function test_ETHEREUM_pauRoleSetOtherwiseUnchanged() public onChain(ChainIdUtils.Ethereum()) {
        // The bridge helpers drain vm.getRecordedLogs(), so read through the same accumulator they use.
        // Everything recorded so far is setup, the previous spell included, and must not be counted.
        uint256 logsBefore = RecordedLogs.getLogs().length;

        executeAllPayloadsAndBridges();

        Vm.Log[] memory logs = RecordedLogs.getLogs();

        uint256 granted;

        for (uint256 i = logsBefore; i < logs.length; ++i) {
            if (
                logs[i].emitter != Ethereum.PAU_ACCESS_CONTROLS &&
                logs[i].emitter != Ethereum.PAU_RATE_LIMITS
            ) continue;

            if (logs[i].topics.length == 0) continue;

            assertTrue(logs[i].topics[0] != ROLE_REVOKED, "unexpected-role-revoked");

            if (logs[i].topics[0] != ROLE_GRANTED) continue;

            assertEq(logs[i].topics[1], DEFAULT_ADMIN_ROLE, "unexpected-role-granted");

            assertEq(
                address(uint160(uint256(logs[i].topics[2]))),
                PAS_CONFIGURATOR,
                "unexpected-role-grantee"
            );

            ++granted;
        }

        assertEq(granted, 2, "unexpected-role-granted-count");
    }

}
