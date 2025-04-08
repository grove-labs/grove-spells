// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, BloomPayloadEthereum } from "src/libraries/BloomPayloadEthereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/bloom-alm-controller/deploy/MainnetControllerInit.sol";

import { MainnetController }               from "lib/bloom-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers, RateLimitData } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

/**
 * @title  Apr 17, 2025 Bloom Ethereum Proposal
 * @notice Activate Bloom Liquidity Layer - initiate ALM system, set rate limits, onboard Morpho Steakhouse Vault
 * @author Steakhouse Financial
 * Forum:  TBD
 * Vote:   TBD
 */
contract BloomEthereum_20250417 is BloomPayloadEthereum {

    address internal constant MORPHO_STEAKHOUSE_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    address internal constant JTRSY_VAULT = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;

    function _execute() internal override {
        initiateAlmSystem();
        setupBasicRateLimits();
        onboardMorphoSteakhouseVault();
        _onboardCentrifugeJTRSY();
    }

    function initiateAlmSystem() private {
        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](0);

        MainnetControllerInit.initAlmSystem({
            vault: Ethereum.ALLOCATOR_VAULT,
            usds: Ethereum.USDS,
            controllerInst: ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : Ethereum.ALM_CONTROLLER,
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            configAddresses: MainnetControllerInit.ConfigAddressParams({
                freezer       : Ethereum.ALM_FREEZER,
                relayer       : Ethereum.ALM_RELAYER,
                oldController : address(0)
            }),
            checkAddresses: MainnetControllerInit.CheckAddressParams({
                admin      : Ethereum.BLOOM_PROXY,
                proxy      : Ethereum.ALM_PROXY,
                rateLimits : Ethereum.ALM_RATE_LIMITS,
                vault      : Ethereum.ALLOCATOR_VAULT,
                psm        : Ethereum.PSM,
                daiUsds    : Ethereum.DAI_USDS,
                cctp       : Ethereum.CCTP_TOKEN_MESSENGER
            }),
            mintRecipients: mintRecipients
        });
    }

    function setupBasicRateLimits() private {
        _setUSDSMintRateLimit(
            10_000_000e18,
            5_000_000e18 / uint256(1 days)
        );
        _setUSDSToUSDCRateLimit(
            10_000_000e6,
            5_000_000e6 / uint256(1 days)
        );
    }

    function onboardMorphoSteakhouseVault() private {
        _onboardERC4626Vault(
            MORPHO_STEAKHOUSE_VAULT,
            5_000_000e6,
            2_500_000e6 / uint256(1 days)
        );
    }

    function _onboardCentrifugeJTRSY() private {
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_DEPOSIT(),
                JTRSY_VAULT
            ),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 5_000_000e6,
                slope     : 2_500_000e6 / uint256(1 days)
            }),
            "jtrsyMintLimit",
            6
        );
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_REDEEM(),
                JTRSY_VAULT
            ),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "jtrsyBurnLimit",
            6
        );
    }

}
