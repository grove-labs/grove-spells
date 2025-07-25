// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/MainnetControllerInit.sol";

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  August 7, 2025 Grove Ethereum Proposal
 * @notice TODO
 * @author Grove Labs
 * Forum : TODO
 * Vote  : TODO
 */
contract GroveEthereum_20250807 is GrovePayloadEthereum {

    address internal constant NEW_MAINNET_CONTROLLER = 0x28170D5084cc3cEbFC5f21f30DB076342716f30C;

    function _execute() internal override {
        _upgradeController();
        _onboardCctpTransfersToAvalanche();
        _migrateCentrifugeJtrsy();
        _migrateCentrifugeJaaa();
        _onboardCentrifugeCrosschainTransfers();
        _onboardEthena();
    }

    function _upgradeController() internal {
        // Define Mainnet relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Ethereum.ALM_RELAYER;

        // Define Avalanche CCTP mint recipients
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

    function _onboardCctpTransfersToAvalanche() internal {
        // TODO: Implement
    }

    function _migrateCentrifugeJtrsy() internal {
        // TODO: Implement
    }

    function _migrateCentrifugeJaaa() internal {
        // TODO: Implement
    }

    function _onboardCentrifugeCrosschainTransfers() internal {
        // TODO: Implement
    }

    function _onboardEthena() internal {
        // TODO: Implement
    }

}
