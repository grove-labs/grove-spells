// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";

import { GroveLiquidityLayerHelpers } from "../helpers/GroveLiquidityLayerHelpers.sol";

import { StarSpell } from "./StarSpell.sol";

/**
 * @dev    Base smart contract for Avalanche.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadAvalanche is StarSpell {

    function _onboardERC7540Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        GroveLiquidityLayerHelpers.onboardERC7540Vault(
            Avalanche.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

    function _setCentrifugeCrosschainTransferRateLimit(address centrifugeVault, uint16 destinationCentrifugeId, uint256 maxAmount, uint256 slope) internal {
        GroveLiquidityLayerHelpers.setCentrifugeCrosschainTransferRateLimit(
            Avalanche.ALM_RATE_LIMITS,
            centrifugeVault,
            destinationCentrifugeId,
            maxAmount,
            slope
        );
    }

}
