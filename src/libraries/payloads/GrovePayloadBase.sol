// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Base } from "lib/grove-address-registry/src/Base.sol";

import { GroveLiquidityLayerHelpers } from "../helpers/GroveLiquidityLayerHelpers.sol";

/**
 * @dev Base smart contract for Base.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadBase {

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        GroveLiquidityLayerHelpers.onboardERC4626Vault(
            Base.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

    function _onboardCurvePool(
        address controller,
        address pool,
        uint256 maxSlippage,
        uint256 swapMax,
        uint256 swapSlope,
        uint256 depositMax,
        uint256 depositSlope,
        uint256 withdrawMax,
        uint256 withdrawSlope
    ) internal {
        GroveLiquidityLayerHelpers.onboardCurvePool(
            controller,
            Base.ALM_RATE_LIMITS,
            pool,
            maxSlippage,
            swapMax,
            swapSlope,
            depositMax,
            depositSlope,
            withdrawMax,
            withdrawSlope
        );
    }

}
