// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Plume } from "lib/grove-address-registry/src/Plume.sol";

import { GroveLiquidityLayerHelpers } from "./GroveLiquidityLayerHelpers.sol";

/**
 * @dev Base smart contract for Plume.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadPlume {

    function _onboardERC7540Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        GroveLiquidityLayerHelpers.onboardERC7540Vault(
            Plume.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

    function _setCentrifugeCrosschainTransferRateLimit(address centrifugeVault, uint16 destinationCentrifugeId, uint256 maxAmount, uint256 slope) internal {
        GroveLiquidityLayerHelpers.setCentrifugeCrosschainTransferRateLimit(
            Plume.ALM_RATE_LIMITS,
            centrifugeVault,
            destinationCentrifugeId,
            maxAmount,
            slope
        );
    }

}
