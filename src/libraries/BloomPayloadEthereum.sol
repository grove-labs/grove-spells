// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum } from "lib/bloom-address-registry/src/Ethereum.sol";

import { BloomLiquidityLayerHelpers } from "./BloomLiquidityLayerHelpers.sol";

/**
 * @dev Base smart contract for Ethereum.
 * @author Steakhouse Financial
 */
abstract contract BloomPayloadEthereum {

    function execute() external {
        _execute();
    }

    function _execute() internal virtual;

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        BloomLiquidityLayerHelpers.onboardERC4626Vault(
            Ethereum.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

    function _setUSDSMintRateLimit(uint256 maxAmount, uint256 slope) internal {
        BloomLiquidityLayerHelpers.setUSDSMintRateLimit(
            Ethereum.ALM_RATE_LIMITS,
            maxAmount,
            slope
        );
    }

    function _setUSDSToUSDCRateLimit(uint256 maxAmount, uint256 slope) internal {
        BloomLiquidityLayerHelpers.setUSDSToUSDCRateLimit(
            Ethereum.ALM_RATE_LIMITS,
            maxAmount,
            slope
        );
    }

}
