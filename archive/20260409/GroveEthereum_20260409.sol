// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";
import { GrovePayloadEthereum }       from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  April 9, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260409 is GrovePayloadEthereum {

    address internal constant MAPLE_SYRUP_USDC = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;

    function _execute() internal override {
        // [Ethereum] Onboard Maple syrupUSDC
        //   Forum : https://forum.skyeco.com/t/april-9th-2026-proposed-changes-to-grove-for-upcoming-spell/27801#p-106019-h-1-ethereum-onboard-maple-syrupusdc-2
        _onboardMapleSyrupUsdc();

        // [Ethereum] Increase JTRSY Deposit Rate Limits
        //   Forum : https://forum.skyeco.com/t/april-9th-2026-proposed-changes-to-grove-for-upcoming-spell/27801#p-106019-h-2-ethereum-increase-jtrsy-deposit-rate-limits-8
        _increaseJtrsyDepositRateLimit();

        // [Ethereum] Increase PSM USDS/USDC Swap Rate Limits
        //   Forum : https://forum.skyeco.com/t/april-9th-2026-proposed-changes-to-grove-for-upcoming-spell/27801#p-106019-h-3-ethereum-increase-psm-usdsusdc-swap-rate-limits-14
        _increasePsmUsdsUsdcSwapRateLimit();
    }

    function _onboardMapleSyrupUsdc() internal {
        MainnetController(Ethereum.ALM_CONTROLLER).setMaxExchangeRate({
            token             : MAPLE_SYRUP_USDC,
            shares            : 1e6,  // BEFORE: 0
            maxExpectedAssets : 3e6   // BEFORE: 0
        });

        bytes32 depositKey = RateLimitHelpers.makeAssetKey({
            key   : GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            asset : MAPLE_SYRUP_USDC
        });

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : depositKey,
            maxAmount : 50_000_000e6,                   // BEFORE: 0
            slope     : 50_000_000e6 / uint256(1 days)  // BEFORE: 0
        });
    }

    function _increaseJtrsyDepositRateLimit() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey({
            key   : GroveLiquidityLayerHelpers.LIMIT_7540_DEPOSIT,
            asset : Ethereum.CENTRIFUGE_JTRSY
        });

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : depositKey,
            maxAmount : 500_000_000e6,                   // BEFORE: 50_000_000e6
            slope     : 500_000_000e6 / uint256(1 days)  // BEFORE: 50_000_000e6 / uint256(1 days)
        });
    }

    function _increasePsmUsdsUsdcSwapRateLimit() internal {
        _setUSDSToUSDCRateLimit({
            maxAmount : 500_000_000e6,                   // BEFORE: 100_000_000e6
            slope     : 500_000_000e6 / uint256(1 days)  // BEFORE: 50_000_000e6 / uint256(1 days)
        });
    }

}
