// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, BloomPayloadEthereum } from "src/libraries/BloomPayloadEthereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/bloom-alm-controller/deploy/MainnetControllerInit.sol";

import { RateLimitHelpers, RateLimitData } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

/**
 * @title  Apr 17, 2025 Bloom Ethereum Proposal
 * @notice Activate Bloom Liquidity Layer - initiate ALM system, set rate limits, onboard Morpho Steakhouse Vault
 * @author Steakhouse Financial
 * Forum:  TBD
 * Vote:   TBD
 */
contract BloomEthereum_20250417 is BloomPayloadEthereum {

    address internal constant FREEZER                 = 0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f;
    address internal constant RELAYER                 = 0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f;
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
                freezer       : FREEZER,
                relayer       : RELAYER,
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
            5_000_000e18,
            2_500_000e18 / uint256(1 days)
        );
        _setUSDSToUSDCRateLimit(
            5_000_000e6,
            2_500_000e6 / uint256(1 days)
        );
    }

    function onboardMorphoSteakhouseVault() private {
        _onboardERC4626Vault(
            MORPHO_STEAKHOUSE_VAULT,
            5_000_000e6,
            2_500_000e6 / uint256(1 days)
        );
    }

}
