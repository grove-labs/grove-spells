// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";
import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { GrovePayloadAvalanche } from "src/libraries/GrovePayloadAvalanche.sol";

/**
 * @title  August 7, 2025 Grove Avalanche Proposal
 * @notice Avalanche Grove Liquidity Layer initialization; onboarding of CCTP transfers to Ethereum; onboarding of Centrifuge JAAA and JTRSY vaults
 * @author Steakhouse Financial
 * Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
 * Vote  : TODO
 */
contract GroveAvalanche_20250807 is GrovePayloadAvalanche {

    address internal constant FAKE_PSM3_PLACEHOLDER  = 0x00000000000000000000000000000000DeaDBeef;
    address internal constant CENTRIFUGE_JAAA_VAULT  = 0x1121F4e21eD8B9BC1BB9A2952cDD8639aC897784;
    address internal constant CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;

    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant JAAA_RATE_LIMIT_MAX    = 100_000_000e6;
    uint256 internal constant JAAA_RATE_LIMIT_SLOPE  = 50_000_000e6 / uint256(1 days);
    uint256 internal constant JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function execute() external {
        // ---------- Grove Liquidity Layer - Initialization ----------
        // Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll  : TODO
        _initializeLiquidityLayer();

        // ---------- Grove Liquidity Layer - Onboard CCTP transfers to Ethereum ----------
        // Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll  : TODO
        _onboardCctpTransfersToEthereum();
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
        bytes32 generalCctpKey = ForeignController(Avalanche.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 ethereumCctpKey = RateLimitHelpers.makeDomainKey(
            ForeignController(Avalanche.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        IRateLimits(Avalanche.ALM_RATE_LIMITS).setUnlimitedRateLimitData(generalCctpKey);

        IRateLimits(Avalanche.ALM_RATE_LIMITS).setRateLimitData({
            key       : ethereumCctpKey,
            maxAmount : CCTP_RATE_LIMIT_MAX,
            slope     : CCTP_RATE_LIMIT_SLOPE
        });

        // Mint recipients are set during the ForeignController initialization
    }

}
