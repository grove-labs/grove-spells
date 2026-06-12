// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ChainId, ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { CommonTestBase } from "./CommonTestBase.sol";

// NOTE: The DPAU contracts (diamond-pau, pau-administered-agent) are compiled
// with solc ^0.8.34 while this repo pins 0.8.25, so we interface with their
// onchain deployments through inline *Like interfaces instead of importing
// their sources (same pattern as pau-assemblers).

interface IPAUControllerLike {
    function accessControls() external view returns (address);
    function beacon() external view returns (address);
    function proxy() external view returns (address);
    function rateLimits() external view returns (address);
}

interface IPAUAccessControlsLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IPAURateLimitsLike {
    function getCurrentRateLimit(bytes32 key) external view returns (uint256 rateLimit);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IPAUProxyLike {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IAdministeredAgentLike {
    function call(address target, bytes memory data) external payable returns (bytes memory result);
}

struct PAUContext {
    address                controller;
    IPAUProxyLike          proxy;
    IPAUAccessControlsLike accessControls;
    IPAURateLimitsLike     rateLimits;
    address                agent;  // AdministeredAgent holding ALLOCATOR_ROLE
    address                actor;  // EOA allowed to drive the agent
}

/// @dev Test base for the DPAU controller system
/// (diamond-pau Controller + AccessControls + AdministeredAgent allocators).
abstract contract CommonPAUTestBase is CommonTestBase {

    bytes32 internal constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant CONTROLLER     = keccak256("CONTROLLER");

    // No PAU addresses exist in grove-address-registry yet, so spell tests
    // configure the context in setUp via _setPAUContext. Once registry
    // constants land, this can resolve them directly like
    // _getGroveLiquidityLayerContext does for the legacy ALM system.
    mapping(ChainId => PAUContext) private pauContext;

    function _setPAUContext(ChainId chain, PAUContext memory ctx) internal {
        pauContext[chain] = ctx;
    }

    function _getPAUContext(ChainId chain) internal view returns (PAUContext memory ctx) {
        ctx = pauContext[chain];
        require(ctx.controller != address(0), "PAU context not configured for chain");
    }

    function _getPAUContext() internal view returns (PAUContext memory) {
        return _getPAUContext(ChainIdUtils.fromUint(block.chainid));
    }

    /**
     * @notice Executes a controller call through the PAU operational path:
     *         actor EOA -> AdministeredAgent.call -> Controller (facet dispatch)
     * @param data The calldata for the controller (facet function selector + args)
     */
    function _callAsPAUActor(bytes memory data) internal returns (bytes memory result) {
        PAUContext memory ctx = _getPAUContext();
        vm.prank(ctx.actor);
        result = IAdministeredAgentLike(ctx.agent).call(ctx.controller, data);
    }

    function _assertPAURateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope
    ) internal view {
        _assertRateLimit(address(_getPAUContext().rateLimits), key, maxAmount, slope, "pau-");
    }

    function _assertPAUUnlimitedRateLimit(
        bytes32 key
    ) internal view {
        _assertUnlimitedRateLimit(address(_getPAUContext().rateLimits), key, "pau-");
    }

    function _assertPAUZeroRateLimit(
        bytes32 key
    ) internal view {
        _assertZeroRateLimit(address(_getPAUContext().rateLimits), key, "pau-");
    }

}
