// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, BloomPayloadEthereum } from "src/libraries/BloomPayloadEthereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/bloom-alm-controller/deploy/MainnetControllerInit.sol";

import { RateLimitHelpers, RateLimitData } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

/**
 * @title  Apr 17, 2025 Bloom Ethereum Proposal
 * @notice Activate Bloom Liquidity Layer
 * @author Steakhouse Financial
 * Forum:  TBD
 * Vote:   TBD
 */
contract BloomEthereum_20250417 is BloomPayloadEthereum {

    // TODO: Confirm these addresses
    address internal constant FREEZER                 = 0x90D8c80C028B4C09C0d8dcAab9bbB057F0513431;
    address internal constant RELAYER                 = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;
    address internal constant MORPHO_STEAKHOUSE_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;


    function _execute() internal override {
        initiateAlmSystem();
        setupBasicRateLimits();
        onboardMorphoSteakhouseVault();
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
            100_000_000e6,                  // TODO: get actual number
            100_000_000e6 / uint256(1 days) // TODO: get actual number
        );
        _setUSDSToUSDCRateLimit(
            100_000_000e6,                  // TODO: get actual number
            100_000_000e6 / uint256(1 days) // TODO: get actual number
        );
    }

    function onboardMorphoSteakhouseVault() private {
        _onboardERC4626Vault(
            MORPHO_STEAKHOUSE_VAULT,
            100_000_000e6,                  // TODO: get actual number
            100_000_000e6 / uint256(1 days) // TODO: get actual number
        );
    }

}
