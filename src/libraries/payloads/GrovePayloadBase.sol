// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Base } from "lib/grove-address-registry/src/Base.sol";

import { GroveLiquidityLayerHelpers } from "../helpers/GroveLiquidityLayerHelpers.sol";

/**
 * @dev    Base smart contract for Base.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadBase {

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope, uint256 shareUnit, uint256 maxAssetsPerShare) internal {
        GroveLiquidityLayerHelpers.onboardERC4626Vault(
            Base.ALM_CONTROLLER,
            Base.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope,
            shareUnit,
            maxAssetsPerShare
        );
    }

}
