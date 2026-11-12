// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Base } from "lib/grove-address-registry/src/Base.sol";

import { RateLimitHelpers } from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";
import { GrovePayloadBase }           from "src/libraries/payloads/GrovePayloadBase.sol";

interface IRateLimitsLike {
    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;
}

/**
 * @title  November 5, 2026 Grove Base Proposal
 * @author Grove Labs
 */
contract GroveBase_20261105 is GrovePayloadBase {

    function execute() external {
        // [Base] Item 1: raise the Grove x Steakhouse USDC Morpho Vault V2 deposit rate limit.
        //   Forum : https://forum.skyeco.com/t/november-5-2026-proposed-changes-to-grove-for-upcoming-spell/28336
        _raiseGroveXSteakhouseUsdcV2MorphoVaultDepositRateLimit();
    }

    function _raiseGroveXSteakhouseUsdcV2MorphoVaultDepositRateLimit() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            Base.GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT
        );

        IRateLimitsLike(Base.ALM_RATE_LIMITS).setRateLimitData({
            key       : depositKey,
            maxAmount : 100_000_000e6,                   // BEFORE: 20_000_000e6
            slope     : 100_000_000e6 / uint256(1 days)  // BEFORE: 20_000_000e6 / 1 days
        });
    }

}
