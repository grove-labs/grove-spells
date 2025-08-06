// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers } from "grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/MainnetControllerInit.sol";

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  August 21, 2025 Grove Ethereum Proposal
 * @author Grove Labs
 * Forum : TODO
 * Vote  : TODO
 */
contract GroveEthereum_20250821 is GrovePayloadEthereum {

    address internal constant NEW_MAINNET_CONTROLLER             = 0x28170D5084cc3cEbFC5f21f30DB076342716f30C; // TODO Change to a proper address
    address internal constant NEW_MAINNET_CENTRIFUGE_JAAA_VAULT  = 0x4880799eE5200fC58DA299e965df644fBf46780B; // TODO Confirm the address
    address internal constant NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A; // TODO Confirm the address

    uint256 internal constant ZERO = 0;

    uint256 internal constant JAAA_DEPOSIT_RATE_LIMIT_MAX   = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant JAAA_DEPOSIT_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant JTRSY_DEPOSIT_RATE_LIMIT_MAX   = 50_000_000e6;                   // TODO Set proper value
    uint256 internal constant JTRSY_DEPOSIT_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint256 internal constant JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                  // TODO Set proper value
    uint256 internal constant JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Set proper value

    uint16 internal constant AVALANCHE_DESTINATION_CENTRIFUGE_ID = 5;

    constructor() {
        // TODO: Set Avalanche payload after deployment
        // PAYLOAD_AVALANCHE = 0x0000000000000000000000000000000000000000;
    }

    function _execute() internal override {
        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _upgradeController();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _offboardOldCentrifugeJaaa();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _offboardOldCentrifugeJtrsy();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _onboardNewCentrifugeJaaa();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _onboardNewCentrifugeJtrsy();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _setCentrifugeCrosschainTransferRecipient();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _onboardCentrifugeJaaaCrosschainTransfer();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _onboardCentrifugeJtrsyCrosschainTransfer();
    }
    function _upgradeController() internal {
        // Define Mainnet relayer
        address[] memory relayers = new address[](1);
        relayers[0] = Ethereum.ALM_RELAYER;

        // Define Avalanche CCTP mint recipient
        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](1);
        mintRecipients[0] = MainnetControllerInit.MintRecipient({
            domain: CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
            mintRecipient: bytes32(uint256(uint160(Avalanche.ALM_PROXY)))
        });

        MainnetControllerInit.upgradeController(
            ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : NEW_MAINNET_CONTROLLER,
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            MainnetControllerInit.ConfigAddressParams({
                freezer       : Ethereum.ALM_FREEZER,
                relayers      : relayers,
                oldController : Ethereum.ALM_CONTROLLER
            }),
            MainnetControllerInit.CheckAddressParams({
                admin      : Ethereum.GROVE_PROXY,
                proxy      : Ethereum.ALM_PROXY,
                rateLimits : Ethereum.ALM_RATE_LIMITS,
                vault      : Ethereum.ALLOCATOR_VAULT,
                psm        : Ethereum.PSM,
                daiUsds    : Ethereum.DAI_USDS,
                cctp       : Ethereum.CCTP_TOKEN_MESSENGER
            }),
            mintRecipients,
            new MainnetControllerInit.LayerZeroRecipient[](0)
        );
    }

    function _offboardOldCentrifugeJaaa() internal {
        bytes32 oldJaaaDepositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_DEPOSIT(),
            Ethereum.CENTRIFUGE_JAAA
        );

        bytes32 oldJaaaRedeemKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_REDEEM(),
            Ethereum.CENTRIFUGE_JAAA
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldJaaaDepositKey,
            maxAmount : ZERO,
            slope     : ZERO
        });

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldJaaaRedeemKey,
            maxAmount : ZERO,
            slope     : ZERO
        });
    }

    function _offboardOldCentrifugeJtrsy() internal {
        bytes32 oldJtrsyDepositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_DEPOSIT(),
            Ethereum.CENTRIFUGE_JTRSY
        );

        bytes32 oldJtrsyRedeemKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_REDEEM(),
            Ethereum.CENTRIFUGE_JTRSY
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldJtrsyDepositKey,
            maxAmount : ZERO,
            slope     : ZERO
        });

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldJtrsyRedeemKey,
            maxAmount : ZERO,
            slope     : ZERO
        });

    }

    function _onboardNewCentrifugeJaaa() internal {
        _onboardERC7540Vault(
            NEW_MAINNET_CENTRIFUGE_JAAA_VAULT,
            JAAA_DEPOSIT_RATE_LIMIT_MAX,
            JAAA_DEPOSIT_RATE_LIMIT_SLOPE
        );
    }

    function _onboardNewCentrifugeJtrsy() internal {
        _onboardERC7540Vault(
            NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT,
            JTRSY_DEPOSIT_RATE_LIMIT_MAX,
            JTRSY_DEPOSIT_RATE_LIMIT_SLOPE
        );
    }

    function _setCentrifugeCrosschainTransferRecipient() internal {
        MainnetController(NEW_MAINNET_CONTROLLER).setCentrifugeRecipient(AVALANCHE_DESTINATION_CENTRIFUGE_ID, bytes32(uint256(uint160(Avalanche.ALM_PROXY))));
    }

    function _onboardCentrifugeJaaaCrosschainTransfer() internal {
        _setCentrifugeCrosschainTransferRateLimit(
            NEW_MAINNET_CENTRIFUGE_JAAA_VAULT,
            AVALANCHE_DESTINATION_CENTRIFUGE_ID,
            JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }

    function _onboardCentrifugeJtrsyCrosschainTransfer() internal {
        _setCentrifugeCrosschainTransferRateLimit(
            NEW_MAINNET_CENTRIFUGE_JTRSY_VAULT,
            AVALANCHE_DESTINATION_CENTRIFUGE_ID,
            JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }

}
