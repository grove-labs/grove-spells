// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  November 13, 2025 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20251113 is GrovePayloadEthereum {

    address internal constant SECURITIZE_USDC_DEPOSIT_WALLET = 0x51e4C4A356784D0B3b698BFB277C626b2b9fe178;
    address internal constant SECURITIZE_USDC_REDEEM_WALLET  = 0xbb543C77436645C8b95B64eEc39E3C0d48D4842b;
    address internal constant SECURITIZE_STAC_CLO            = 0x51C2d74017390CbBd30550179A16A1c28F7210fc;

    uint256 internal constant SECURITIZE_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant SECURITIZE_USDC_DEPOSIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {
        // TODO: Item title
        //   Forum : TODO: Forum link
        _onboardMorphoVault(); // TODO: Rename to more precisely describe the onboarding

        // TODO: Item title
        //   Forum : TODO: Forum link
        _onboardSecuritize(); // TODO: Rename to more precisely describe the onboarding

        // TODO: Item title
        //   Forum : TODO: Forum link
        _onboardCurvePool(); // TODO: Rename to more precisely describe the onboarding

        // TODO: Item title
        //   Forum : TODO: Forum link
        _onboardCctpToBase(); // TODO: Rename to more precisely describe the onboarding
    }

    function _onboardMorphoVault() internal {
        // TODO: Implement
    }

    function _onboardSecuritize() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            SECURITIZE_USDC_DEPOSIT_WALLET
        );

        bytes32 redeemKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            SECURITIZE_STAC_CLO,
            SECURITIZE_USDC_REDEEM_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            depositKey,
            SECURITIZE_USDC_DEPOSIT_MAX,
            SECURITIZE_USDC_DEPOSIT_SLOPE
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setUnlimitedRateLimitData(redeemKey);
    }

    function _onboardCurvePool() internal {
        // TODO: Implement
    }

    function _onboardCctpToBase() internal {
        // TODO: Implement
    }

}
