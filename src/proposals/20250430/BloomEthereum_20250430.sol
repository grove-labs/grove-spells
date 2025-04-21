// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, BloomPayloadEthereum } from "src/libraries/BloomPayloadEthereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/bloom-alm-controller/deploy/MainnetControllerInit.sol";

import { MainnetController } from "lib/bloom-alm-controller/src/MainnetController.sol";

/**
 * @title  April 30, 2025 Bloom Ethereum Proposal
 * @notice Activate Bloom Liquidity Layer - initiate ALM system, set rate limits, onboard Centrifuge Vault
 * @author Steakhouse Financial
 * Forum: https://forum.sky.money/t/technical-test-of-of-the-star2-allocation-system/26289
 * Vote:  TODO: add vote link
 */
contract BloomEthereum_20250430 is BloomPayloadEthereum {

    address internal constant CENTRIFUGE_VAULT = 0xE9d1f733F406D4bbbDFac6D4CfCD2e13A6ee1d01;

    function _execute() internal override {
        _initiateAlmSystem();
        _setupBasicRateLimits();
        _onboardCentrifugeVault();
    }

    function _initiateAlmSystem() private {
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

    function _setupBasicRateLimits() private {
        _setUSDSMintRateLimit(
            100_000_000e18,
            50_000_000e18 / uint256(1 days)
        );
        _setUSDSToUSDCRateLimit(
            100_000_000e6,
            50_000_000e6 / uint256(1 days)
        );
    }
    function _onboardCentrifugeVault() private {
        _onboardERC7540Vault(
            CENTRIFUGE_VAULT,
            100_000_000e6,
            50_000_000e6 / uint256(1 days)
        );
    }

}
