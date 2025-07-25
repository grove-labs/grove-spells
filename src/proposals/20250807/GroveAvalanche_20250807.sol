// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { GrovePayloadAvalanche } from "src/libraries/GrovePayloadAvalanche.sol";

/**
 * @title  August 7, 2025 Grove Avalanche Proposal
 * @notice TODO
 * @author Steakhouse Financial
 * Forum : TODO
 * Vote  : TODO
 */
contract GroveAvalanche_20250807 is GrovePayloadAvalanche {

    address internal constant FAKE_PSM3_PLACEHOLDER  = 0x00000000000000000000000000000000DeaDBeef;
    address internal constant CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;
    address internal constant CENTRIFUGE_JAAA_VAULT  = 0x1121F4e21eD8B9BC1BB9A2952cDD8639aC897784;

    uint256 internal constant JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);
    uint256 internal constant JAAA_RATE_LIMIT_MAX    = 100_000_000e6;
    uint256 internal constant JAAA_RATE_LIMIT_SLOPE  = 50_000_000e6 / uint256(1 days);

    function execute() external {
        _initializeLiquidityLayer();
        _onboardCctpTransfersToEthereum();
        _onboardCentrifugeJtrsy();
        _onboardCentrifugeJaaa();
    }

    function _initializeLiquidityLayer() internal {
        // Define Avalanche relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Avalanche.ALM_RELAYER;

        // Define Mainnet CCTP mint recipients
        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](1);
        mintRecipients[0] = ForeignControllerInit.MintRecipient({
            domain: CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient: bytes32(uint256(uint160(Ethereum.ALM_PROXY)))
        });

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : Avalanche.ALM_PROXY,
                controller : Avalanche.ALM_CONTROLLER,
                rateLimits : Avalanche.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Avalanche.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin      : Avalanche.GROVE_EXECUTOR,
                psm        : FAKE_PSM3_PLACEHOLDER,
                cctp       : Avalanche.CCTP_TOKEN_MESSENGER,
                usdc       : Avalanche.USDC
            }),
            mintRecipients,
            new ForeignControllerInit.LayerZeroRecipient[](0)
        );
    }

    function _onboardCctpTransfersToEthereum() internal {
        // TODO: Implement
    }

    function _onboardCentrifugeJtrsy() internal {
        _onboardERC7540Vault(
            CENTRIFUGE_JTRSY_VAULT,
            JTRSY_RATE_LIMIT_MAX,
            JTRSY_RATE_LIMIT_SLOPE
        );
    }

    function _onboardCentrifugeJaaa() internal {
        _onboardERC7540Vault(
            CENTRIFUGE_JAAA_VAULT,
            JAAA_RATE_LIMIT_MAX,
            JAAA_RATE_LIMIT_SLOPE
        );
    }

}
