// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, BloomPayloadEthereum } from "src/libraries/BloomPayloadEthereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/bloom-alm-controller/deploy/MainnetControllerInit.sol";

import { MainnetController } from "lib/bloom-alm-controller/src/MainnetController.sol";

/**
 * @title  May 1, 2025 Bloom Ethereum Proposal
 * @notice Activate Bloom Liquidity Layer - initiate ALM system, set rate limits, onboard JTRSY and JAAA Centrifuge Vaults
 * @author Steakhouse Financial
 * Forum:  TODO: add forum link
 * Vote:   TODO: add vote link
 */
contract BloomEthereum_20250501 is BloomPayloadEthereum {

    address internal constant JTRSY_VAULT = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;
    address internal constant JAAA_VAULT  = 0xdEADBEeF00000000000000000000000000000000; // TODO: add address

    function _execute() internal override {
        _initiateAlmSystem();
        _setupBasicRateLimits();
        _onboardCentrifugeJTRSY();
        // _onboardCentrifugeJAAA(); // TODO: uncomment when JAAA address is confirmed
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
            100_000e18,
            50_000e18 / uint256(1 days)
        );
        _setUSDSToUSDCRateLimit(
            100_000e6,
            50_000e6 / uint256(1 days)
        );
    }

    function _onboardCentrifugeJTRSY() private {
        _onboardERC7540Vault(
            JTRSY_VAULT,
            100_000e6,
            50_000e6 / uint256(1 days)
        );
    }

    function _onboardCentrifugeJAAA() private {
        _onboardERC7540Vault(
            JAAA_VAULT,
            100_000_000e6,
            10_000_000e6 / uint256(1 days)
        );
    }

}
