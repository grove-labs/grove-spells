// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum as GroveContracts } from "lib/grove-address-registry/src/Ethereum.sol";
import { Ethereum as SparkContracts } from "lib/spark-address-registry/src/Ethereum.sol";

import { MainnetController }               from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers, RateLimitData } from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { AllocatorBuffer } from 'lib/dss-allocator/src/AllocatorBuffer.sol';
import { AllocatorVault }  from 'lib/dss-allocator/src/AllocatorVault.sol';

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  July 24, 2025 Grove Ethereum Proposal
 * @notice Onboarding of Centrifuge JTRSY and Blackrock BUIDL; transfer of USDS to Spark
 * @author Steakhouse Financial
 * Forum (JTRSY and BUIDL onboarding) : https://forum.sky.money/t/july-24-2025-proposed-onboardings-for-grove-in-upcoming-spell/26805:
 * Forum (Transfer of USDS to Spark)  : https://forum.sky.money/t/tokenized-t-bills-transfer-from-spark-to-grove/26785
 * Vote (BUIDL onboarding)            : https://vote.sky.money/polling/QmdkNnmE
 * Vote (JTRSY onboarding)            : https://vote.sky.money/polling/QmdKd2se
 * Vote (Transfer of USDS to Spark)   : https://vote.sky.money/polling/Qme5qebN
 */
contract GroveEthereum_20250724 is GrovePayloadEthereum {

    address internal constant CENTRIFUGE_JTRSY        = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;
    address internal constant BUIDL                   = 0x6a9DA2D710BB9B700acde7Cb81F10F1fF8C89041;
    address internal constant BUIDL_DEPOSIT           = 0xD1917664bE3FdAea377f6E8D5BF043ab5C3b1312;
    address internal constant BUIDL_REDEEM            = 0x8780Dd016171B91E4Df47075dA0a947959C34200;
    address internal constant MORPHO_STEAKHOUSE_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    uint256 internal constant JTRSY_USDS_MINT_AMOUNT = 404_016_484e18;
    uint256 internal constant JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);
    uint256 internal constant BUIDL_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant BUIDL_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {
        // ---------- Grove Liquidity Layer - Onboard Centrifuge JTRSY ----------
        // Forum : https://forum.sky.money/t/july-24-2025-proposed-onboardings-for-grove-in-upcoming-spell/26805
        // Poll  : https://vote.sky.money/polling/QmdKd2se
        _onboardCentrifugeJTRSY();

        // ---------- Grove Liquidity Layer - Onboard BlackRock BUIDL-I ----------
        // Forum : https://forum.sky.money/t/july-24-2025-proposed-onboardings-for-grove-in-upcoming-spell/26805
        // Poll  : https://vote.sky.money/polling/QmdkNnmE
        _onboardBlackrockBUIDL();

        // ---------- Mint USDS for BUIDL and JTRSY tokens and send it to Spark Allocator Buffer ----------
        // Forum : https://forum.sky.money/t/july-24-2025-proposed-changes-to-spark-for-upcoming-spell/26796
        // Poll  : https://vote.sky.money/polling/Qme5qebN
        _sendUSDSToSpark();
    }

    function _onboardCentrifugeJTRSY() private {
        _onboardERC7540Vault(
            CENTRIFUGE_JTRSY,
            JTRSY_RATE_LIMIT_MAX,
            JTRSY_RATE_LIMIT_SLOPE
        );
    }

    function _onboardBlackrockBUIDL() private {
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(GroveContracts.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                GroveContracts.USDC,
                BUIDL_DEPOSIT
            ),
            GroveContracts.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : BUIDL_RATE_LIMIT_MAX,
                slope     : BUIDL_RATE_LIMIT_SLOPE
            }),
            "buidlMintLimit",
            6
        );

        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(GroveContracts.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                BUIDL,
                BUIDL_REDEEM
            ),
            GroveContracts.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "buidlBurnLimit",
            6
        );
    }

    function _sendUSDSToSpark() private {
        uint256 buidlUsdsMintAmount = IERC20(BUIDL).balanceOf(SparkContracts.ALM_PROXY) * 1e12;
        uint256 totalUsdsMintAmount = buidlUsdsMintAmount + JTRSY_USDS_MINT_AMOUNT;

        AllocatorVault(GroveContracts.ALLOCATOR_VAULT).draw(totalUsdsMintAmount);
        AllocatorBuffer(GroveContracts.ALLOCATOR_BUFFER).approve(GroveContracts.USDS, address(this), totalUsdsMintAmount);
        IERC20(GroveContracts.USDS).transferFrom(GroveContracts.ALLOCATOR_BUFFER, SparkContracts.ALM_PROXY, totalUsdsMintAmount);
    }

}
