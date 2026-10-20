// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";

import { GrovePayloadAvalanche } from "src/libraries/payloads/GrovePayloadAvalanche.sol";

interface IALMProxyLike {
    function CONTROLLER() external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function doCallWithValue(address target, bytes memory data, uint256 value) external payable returns (bytes memory);
}

/**
 * @title  November 5, 2026 Grove Avalanche Proposal
 * @author Grove Labs
 */
contract GroveAvalanche_20261105 is GrovePayloadAvalanche {

    address internal constant GROVE_FOUNDATION = 0xE3EC4CC359E68c9dCE15Bf667b1aD37Df54a5a42;

    function execute() external {
        // [Avalanche] Item 1: transfer the ALM Proxy's AVAX to the Grove Foundation Multisig.
        //   Forum : TODO
        _transferAvaxToGroveFoundation();
    }

    function _transferAvaxToGroveFoundation() internal {
        IALMProxyLike almProxy = IALMProxyLike(Avalanche.ALM_PROXY);
        bytes32 controllerRole = almProxy.CONTROLLER();

        almProxy.grantRole(controllerRole, Avalanche.GROVE_EXECUTOR);
        almProxy.doCallWithValue(GROVE_FOUNDATION, "", 480_481.63e18);
        almProxy.revokeRole(controllerRole, Avalanche.GROVE_EXECUTOR);
    }

}
