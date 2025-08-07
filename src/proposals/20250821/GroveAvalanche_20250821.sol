// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";

import { GrovePayloadAvalanche } from "src/libraries/GrovePayloadAvalanche.sol";

/**
 * @title  August 21, 2025 Grove Avalanche Proposal
 * @author Grove Labs
 * Forum : TODO
 * Vote  : TODO
 */
contract GroveAvalanche_20250821 is GrovePayloadAvalanche {

    address internal constant NEW_AVALANCHE_CONTROLLER             = 0xbA41d5F95DF891862bf28bEA261AEc0efd6D0FAA; // TODO Change to a proper address
    address internal constant NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT  = 0x1121F4e21eD8B9BC1BB9A2952cDD8639aC897784;
    address internal constant NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;

    uint256 internal constant JAAA_DEPOSIT_RATE_LIMIT_MAX   = 50_000_000e6;                   // TODO Confirm value
    uint256 internal constant JAAA_DEPOSIT_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Confirm value

    uint256 internal constant JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 50_000_000e6;                   // TODO Confirm value
    uint256 internal constant JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Confirm value

    uint256 internal constant JTRSY_DEPOSIT_RATE_LIMIT_MAX   = 50_000_000e6;                   // TODO Confirm value
    uint256 internal constant JTRSY_DEPOSIT_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Confirm value

    uint256 internal constant JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 50_000_000e6;                   // TODO Confirm value
    uint256 internal constant JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days); // TODO Confirm value

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID = 1;

    function execute() external {
        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _upgradeController();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _onboardCentrifugeJaaa();

        // TODO Add spell item title
        // Forum : TODO Add forum link
        // Poll  : TODO Add poll link
        _onboardCentrifugeJtrsy();

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
        // Define Avalanche relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Avalanche.ALM_RELAYER;

        // Define Mainnet CCTP mint recipients
        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](1);
        mintRecipients[0] = ForeignControllerInit.MintRecipient({
            domain: CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient: bytes32(uint256(uint160(Ethereum.ALM_PROXY)))
        });

        address avalanchePlaceholderPsmAddress = address(ForeignController(Avalanche.ALM_CONTROLLER).psm());

        ForeignControllerInit.upgradeController(
            ControllerInstance({
                almProxy   : Avalanche.ALM_PROXY,
                controller : NEW_AVALANCHE_CONTROLLER,
                rateLimits : Avalanche.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Avalanche.ALM_FREEZER,
                relayers      : relayers,
                oldController : Avalanche.ALM_CONTROLLER
            }),
            ForeignControllerInit.CheckAddressParams({
                admin : Avalanche.GROVE_EXECUTOR,
                psm   : avalanchePlaceholderPsmAddress,
                cctp  : Avalanche.CCTP_TOKEN_MESSENGER,
                usdc  : Avalanche.USDC
            }),
            mintRecipients,
            new ForeignControllerInit.LayerZeroRecipient[](0)
        );
    }

    function _onboardCentrifugeJaaa() internal {
        _onboardERC7540Vault(
            NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT,
            JAAA_DEPOSIT_RATE_LIMIT_MAX,
            JAAA_DEPOSIT_RATE_LIMIT_SLOPE
        );
    }

    function _onboardCentrifugeJtrsy() internal {
        _onboardERC7540Vault(
            NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT,
            JTRSY_DEPOSIT_RATE_LIMIT_MAX,
            JTRSY_DEPOSIT_RATE_LIMIT_SLOPE
        );
    }

    function _setCentrifugeCrosschainTransferRecipient() internal {
        ForeignController(NEW_AVALANCHE_CONTROLLER).setCentrifugeRecipient(ETHEREUM_DESTINATION_CENTRIFUGE_ID, bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    }

    function _onboardCentrifugeJaaaCrosschainTransfer() internal {
        _setCentrifugeCrosschainTransferRateLimit(
            NEW_AVALANCHE_CENTRIFUGE_JAAA_VAULT,
            ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            JAAA_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }

    function _onboardCentrifugeJtrsyCrosschainTransfer() internal {
        _setCentrifugeCrosschainTransferRateLimit(
            NEW_AVALANCHE_CENTRIFUGE_JTRSY_VAULT,
            ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }

}
