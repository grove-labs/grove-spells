// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, BloomPayloadEthereum } from "src/libraries/BloomPayloadEthereum.sol";

import { MainnetController } from "lib/bloom-alm-controller/src/MainnetController.sol";

import { RateLimitHelpers, RateLimitData } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

/**
 * @title  May 29, 2025 Bloom Ethereum Proposal
 * @notice TODO: Add details
 * @author Steakhouse Financial
 * Forum: TODO: Add link
 * Vote:  TODO: Add link
 */
contract BloomEthereum_20250529 is BloomPayloadEthereum {

    address internal constant CENTRIFUGE_JTRSY = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;

    address internal constant BUIDL         = 0x6a9DA2D710BB9B700acde7Cb81F10F1fF8C89041;
    address internal constant BUIDL_DEPOSIT = 0xD1917664bE3FdAea377f6E8D5BF043ab5C3b1312;
    address internal constant BUIDL_REDEEM  = 0x8780Dd016171B91E4Df47075dA0a947959C34200;

    function _execute() internal override {
        _onboardCentrifugeJTRSY();
        _onboardBlackrockBUIDL();
        _onboardSuperstateUSTB();
    }

    function _onboardCentrifugeJTRSY() private {
        _onboardERC7540Vault(
            CENTRIFUGE_JTRSY,
            100_000_000e6, // TODO: Get actual numbers
            50_000_000e6 / uint256(1 days)  // TODO: Get actual numbers
        );
    }

    function _onboardBlackrockBUIDL() private {
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                Ethereum.USDC,
                BUIDL_DEPOSIT
            ),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 100_000_000e6, // TODO: Get actual numbers
                slope     : 50_000_000e6 / uint256(1 days) // TODO: Get actual numbers
            }),
            "buidlMintLimit",
            6
        );

        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                BUIDL,
                BUIDL_REDEEM
            ),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "buidlBurnLimit",
            6
        );
    }

    function _onboardSuperstateUSTB() private {
        RateLimitHelpers.setRateLimitData(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_SUPERSTATE_SUBSCRIBE(),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 100_000_000e6, // TODO: Get actual numbers
                slope     : 50_000_000e6 / uint256(1 days) // TODO: Get actual numbers
            }),
            "ustbMintLimit",
            6
        );
        // Instant liquidity redemption
        RateLimitHelpers.setRateLimitData(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_SUPERSTATE_REDEEM(),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "ustbBurnLimit",
            6
        );
        // Offchain redemption
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                Ethereum.USTB,
                Ethereum.USTB
            ),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "ustbOffchainBurnLimit",
            6
        );
    }

}
