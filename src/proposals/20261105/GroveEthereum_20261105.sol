// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { RateLimitHelpers } from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";
import { GrovePayloadEthereum }        from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUsdsPsmWrapperLike {
    function sellGem(address usr, uint256 gemAmt) external returns (uint256 usdsOut);
}

interface IRateLimitsLike {
    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;
}

/**
 * @title  November 5, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20261105 is GrovePayloadEthereum {

    constructor() {
        PAYLOAD_BASE = address(0); // TODO: set after foreign payload deploy
    }

    function _execute() internal override {
        // [Ethereum] Item 2: raise the Grove x Steakhouse USDC Morpho Vault V2 deposit rate limit.
        //   Forum : https://forum.skyeco.com/t/november-5-2026-proposed-changes-to-grove-for-upcoming-spell/28336
        _raiseGroveXSteakhouseUsdcV2MorphoVaultDepositRateLimit();

        // [Ethereum] Item 3: swap the Grove SubProxy's USDC to USDS.
        //   Forum : https://forum.skyeco.com/t/november-5-2026-proposed-changes-to-grove-for-upcoming-spell/28336
        _swapUsdcToUsdsViaPsm();
    }

    function _raiseGroveXSteakhouseUsdcV2MorphoVaultDepositRateLimit() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT
        );

        IRateLimitsLike(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : depositKey,
            maxAmount : 100_000_000e6,                   // BEFORE: 20_000_000e6
            slope     : 100_000_000e6 / uint256(1 days)  // BEFORE: 20_000_000e6 / 1 days
        });
    }

    function _swapUsdcToUsdsViaPsm() internal {
        require(
            IERC20Like(Ethereum.USDC).approve(
                Ethereum.WRAPPER_USDS_LITE_PSM_USDC_A,
                1_484_740_589999
            )
        );
        IUsdsPsmWrapperLike(Ethereum.WRAPPER_USDS_LITE_PSM_USDC_A).sellGem(
            address(this),
            1_484_740_589999
        );
    }

}
