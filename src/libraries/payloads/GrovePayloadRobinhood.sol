// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Robinhood } from "lib/grove-address-registry/src/Robinhood.sol";

import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GroveLiquidityLayerHelpers } from "../helpers/GroveLiquidityLayerHelpers.sol";

/**
 * @dev    Base smart contract for Robinhood.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadRobinhood {

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope, uint256 shareUnit, uint256 maxAssetsPerShare) internal {
        GroveLiquidityLayerHelpers.onboardERC4626Vault(
            Robinhood.ALM_CONTROLLER,
            Robinhood.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope,
            shareUnit,
            maxAssetsPerShare
        );
    }

    function _onboardAssetTransfer(address asset, address destination, uint256 maxAmount, uint256 slope) internal {
        bytes32 transferKey = RateLimitHelpers.makeAssetDestinationKey(
            ForeignController(Robinhood.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            asset,
            destination
        );

        IRateLimits(Robinhood.ALM_RATE_LIMITS).setRateLimitData(transferKey, maxAmount, slope);
    }

}
