// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum as BloomContracts } from "lib/bloom-address-registry/src/Ethereum.sol";
import { Ethereum as SparkContracts } from "lib/spark-address-registry/src/Ethereum.sol";

import { MainnetController }               from "lib/bloom-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers, RateLimitData } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

import { BloomPayloadEthereum } from "src/libraries/BloomPayloadEthereum.sol";

/**
 * @title  June 12, 2025 Bloom Ethereum Proposal
 * @notice Onboarding of Centrifuge JTRSY, Blackrock BUIDL, and Superstate USTB
 * @author Steakhouse Financial
 * Forum: TODO: Add link
 * Vote:  TODO: Add link
 */
contract BloomEthereum_20250612 is BloomPayloadEthereum {

    address internal constant CENTRIFUGE_JTRSY = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;

    address internal constant BUIDL         = 0x6a9DA2D710BB9B700acde7Cb81F10F1fF8C89041; // TODO: Confirm this address
    address internal constant BUIDL_DEPOSIT = 0xD1917664bE3FdAea377f6E8D5BF043ab5C3b1312; // TODO: Confirm this address
    address internal constant BUIDL_REDEEM  = 0x8780Dd016171B91E4Df47075dA0a947959C34200; // TODO: Confirm this address

    function _execute() internal override {
        _onboardCentrifugeJTRSY();
        _onboardBlackrockBUIDL();
        _onboardSuperstateUSTB();
        _onboardSparkUSDSTransfers();
    }

    function _onboardCentrifugeJTRSY() private {
        _onboardERC7540Vault(
            CENTRIFUGE_JTRSY,
            50_000_000e6, // TODO: Get actual numbers
            50_000_000e6 / uint256(1 days)  // TODO: Get actual numbers
        );
    }

    function _onboardBlackrockBUIDL() private {
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(BloomContracts.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                BloomContracts.USDC,
                BUIDL_DEPOSIT
            ),
            BloomContracts.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 50_000_000e6, // TODO: Get actual numbers
                slope     : 50_000_000e6 / uint256(1 days) // TODO: Get actual numbers
            }),
            "buidlMintLimit",
            6
        );

        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(BloomContracts.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                BUIDL,
                BUIDL_REDEEM
            ),
            BloomContracts.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "buidlBurnLimit",
            6
        );
    }

    function _onboardSuperstateUSTB() private {
        RateLimitHelpers.setRateLimitData(
            MainnetController(BloomContracts.ALM_CONTROLLER).LIMIT_SUPERSTATE_SUBSCRIBE(),
            BloomContracts.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 50_000_000e6, // TODO: Get actual numbers
                slope     : 50_000_000e6 / uint256(1 days) // TODO: Get actual numbers
            }),
            "ustbMintLimit",
            6
        );
        // Instant liquidity redemption
        RateLimitHelpers.setRateLimitData(
            MainnetController(BloomContracts.ALM_CONTROLLER).LIMIT_SUPERSTATE_REDEEM(),
            BloomContracts.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "ustbBurnLimit",
            6
        );
        // Offchain redemption
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(BloomContracts.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                BloomContracts.USTB,
                BloomContracts.USTB
            ),
            BloomContracts.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "ustbOffchainBurnLimit",
            6
        );
    }

    function _onboardSparkUSDSTransfers() private {
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(BloomContracts.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                BloomContracts.USDS,
                SparkContracts.ALM_PROXY
            ),
            BloomContracts.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 50_000_000e18, // TODO: Get actual numbers
                slope     : 50_000_000e18 / uint256(1 days) // TODO: Get actual numbers
            }),
            "sparkUsdsTransferLimit",
            18
        );
    }

}
