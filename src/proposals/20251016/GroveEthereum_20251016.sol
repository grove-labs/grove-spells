// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  October 16, 2025 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20251016 is GrovePayloadEthereum {

    address internal constant FALCON_X_DEPOSIT = 0xD94F9ef3395BBE41C1f05ced3C9a7dc520D08036;

    uint256 internal constant FALCON_X_USDC_TRANSFER_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant FALCON_X_USDC_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {
        // TODO Item title
        //   Forum : TODO Forum link
        //   Poll  : TODO Poll link
        _onboardFalconXDeposits();
    }

    function _onboardFalconXDeposits() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            FALCON_X_DEPOSIT
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            depositKey,
            FALCON_X_USDC_TRANSFER_RATE_LIMIT_MAX,
            FALCON_X_USDC_TRANSFER_RATE_LIMIT_SLOPE
        );
    }

}
