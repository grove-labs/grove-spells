// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Plasma } from "lib/grove-address-registry/src/Plasma.sol";

import { GroveLiquidityLayerHelpers } from "../helpers/GroveLiquidityLayerHelpers.sol";

/**
 * @dev Base smart contract for Plasma.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadPlasma {

    function _onboardAaveToken(address token, uint256 depositMax, uint256 depositSlope) internal {
        GroveLiquidityLayerHelpers.onboardAaveToken(
            Plasma.ALM_RATE_LIMITS,
            token,
            depositMax,
            depositSlope
        );
    }

}
