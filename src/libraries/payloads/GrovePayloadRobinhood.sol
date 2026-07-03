// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GroveLiquidityLayerHelpers } from "../helpers/GroveLiquidityLayerHelpers.sol";

/**
 * @dev    Base smart contract for Robinhood (Arbitrum Orbit L2, chain ID 4663).
 * @author Steakhouse Financial
 * @notice ALM addresses are local constants until grove-address-registry exposes Robinhood.* references
 *         (swapped in the archive PR).
 */
abstract contract GrovePayloadRobinhood {

    address internal constant ALM_CONTROLLER  = 0x2c10885ddec8d52ecF3Ad2B3833765bf36eD80cf;
    address internal constant ALM_RATE_LIMITS = 0xC13e5ff7993c5df911aE562a7736B0eBA12b2010;

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope, uint256 shareUnit, uint256 maxAssetsPerShare) internal {
        GroveLiquidityLayerHelpers.onboardERC4626Vault(
            ALM_CONTROLLER,
            ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope,
            shareUnit,
            maxAssetsPerShare
        );
    }

    function _onboardAssetTransfer(address asset, address destination, uint256 maxAmount, uint256 slope) internal {
        bytes32 transferKey = RateLimitHelpers.makeAssetDestinationKey(
            ForeignController(ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            asset,
            destination
        );

        IRateLimits(ALM_RATE_LIMITS).setRateLimitData(transferKey, maxAmount, slope);
    }

}
