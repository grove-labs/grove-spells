// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";

import { GroveLiquidityLayerHelpers } from "./GroveLiquidityLayerHelpers.sol";

/**
 * @dev Base smart contract for Avalanche.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadAvalanche {

    function _onboardERC7540Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        GroveLiquidityLayerHelpers.onboardERC7540Vault(
            Avalanche.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

}
