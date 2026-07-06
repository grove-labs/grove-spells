// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ChainId, ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { CommonTestBase } from "./CommonTestBase.sol";

// NOTE: The PAU contracts (diamond-pau, pau-administered-agent) are compiled
// with solc ^0.8.34 while this repo pins 0.8.25, so we interface with their
// onchain deployments through inline *Like interfaces instead of importing
// their sources (same pattern as pau-assemblers).

// Mirrors IEnumerableIntegrations.Dispatch: the facet and delegate selector a
// call selector resolves to on the controller (zero facet = not wired).
struct PauDispatch {
    address facet;
    bytes4  delegateSelector;
}

// Shared controller surface most facet tests need: the controller admin views
// plus the base facet entrypoints/getters (USDS mint/burn via Sky's allocator
// instance, PSM USDS<>USDC swaps). Per-facet *ControllerLike interfaces inherit
// this so these are declared once, not in every <Facet>TestingBase.sol.
interface IPauBaseControllerLike {
    function accessControls() external view returns (address);
    function beacon() external view returns (address);
    function getDispatch(bytes4 callSelector) external view returns (PauDispatch memory dispatch);
    function proxy() external view returns (address);
    function rateLimits() external view returns (address);

    function usds_VERSION() external view returns (string memory);
    function usds_usds() external view returns (address);
    function usds_setVault(address vault) external;
    function usds_mint(uint256 usdsAmount) external returns (uint256);
    function usds_burn(uint256 usdsAmount) external returns (uint256);
    function usds_vault() external view returns (address);
    function usds_mintRateLimitKey() external view returns (bytes32);
    function usds_burnRateLimitKey() external view returns (bytes32);

    function psm_VERSION() external view returns (string memory);
    function psm_dai() external view returns (address);
    function psm_daiUSDS() external view returns (address);
    function psm_psm() external view returns (address);
    function psm_usdc() external view returns (address);
    function psm_usds() external view returns (address);
    function psm_to18ConversionFactor() external view returns (uint256);
    function psm_swapUSDSToUSDC(uint256 usdcAmount) external returns (uint256);
    function psm_swapUSDCToUSDS(uint256 usdcAmount) external returns (uint256);
    function psm_usdsToUSDCSwapRateLimitKey() external view returns (bytes32);
    function psm_usdcToUSDSSwapRateLimitKey() external view returns (bytes32);
}

interface IPauAccessControlsLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

interface IPauRateLimitsLike {
    function getCurrentRateLimit(bytes32 key) external view returns (uint256 rateLimit);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IPauProxyLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IAdministeredAgentLike {
    function call(address target, bytes memory data) external payable returns (bytes memory result);
}

struct PauContext {
    address                controller;
    IPauProxyLike          proxy;
    IPauAccessControlsLike accessControls;
    IPauRateLimitsLike     rateLimits;
    address                agent;  // AdministeredAgent holding ALLOCATOR_ROLE
    address                actor;  // EOA allowed to drive the agent
}

/// @dev Test base for the PAU controller system
/// (diamond-pau Controller + AccessControls + AdministeredAgent allocators).
abstract contract CommonPauTestBase is CommonTestBase {

    bytes32 internal constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant CONTROLLER     = keccak256("CONTROLLER");

    // No PAU addresses exist in grove-address-registry yet, so spell tests
    // configure the context in setUp via _setPauContext. Once registry
    // constants land, this can resolve them directly like
    // _getGroveLiquidityLayerContext does for the legacy ALM system.
    mapping(ChainId => PauContext) private pauContext;

    function _setPauContext(ChainId chain, PauContext memory ctx) internal {
        pauContext[chain] = ctx;
    }

    function _getPauContext(ChainId chain) internal view returns (PauContext memory ctx) {
        ctx = pauContext[chain];
        require(ctx.controller != address(0), "PAU context not configured for chain");
    }

    function _getPauContext() internal view returns (PauContext memory ctx) {
        ctx = _getPauContext(ChainIdUtils.fromUint(block.chainid));

        // Contexts are hand-configured until registry constants land, so
        // cross-check against the controller's own references to catch typos.
        // Only this variant validates: block.chainid guarantees the active
        // fork matches the context being checked.
        IPauBaseControllerLike controller = IPauBaseControllerLike(ctx.controller);
        require(controller.proxy()          == address(ctx.proxy),          "PAU context proxy mismatch");
        require(controller.rateLimits()     == address(ctx.rateLimits),     "PAU context rateLimits mismatch");
        require(controller.accessControls() == address(ctx.accessControls), "PAU context accessControls mismatch");
    }

    /**
     * @notice Executes a controller call through the PAU operational path:
     *         actor EOA -> AdministeredAgent.call -> Controller (facet dispatch)
     * @dev    Takes the caller's already-loaded (and validated) context so the
     *         agent call is the first external call after any preceding
     *         vm.expectRevert. Fetching the context here would fire the
     *         validating staticcalls in _getPauContext() first, and Foundry
     *         would bind expectRevert to those instead of the controller call.
     * @param ctx  The PAU context (load once via _getPauContext()).
     * @param data The calldata for the controller (facet function selector + args)
     */
    function _callAsPauActor(PauContext memory ctx, bytes memory data) internal returns (bytes memory result) {
        vm.prank(ctx.actor);
        result = IAdministeredAgentLike(ctx.agent).call(ctx.controller, data);
    }

    function _assertPauRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope
    ) internal view {
        _assertRateLimit(address(_getPauContext().rateLimits), key, maxAmount, slope, "pau-");
    }

    function _assertPauUnlimitedRateLimit(
        bytes32 key
    ) internal view {
        _assertUnlimitedRateLimit(address(_getPauContext().rateLimits), key, "pau-");
    }

    function _assertPauZeroRateLimit(
        bytes32 key
    ) internal view {
        _assertZeroRateLimit(address(_getPauContext().rateLimits), key, "pau-");
    }

}
