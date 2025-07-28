// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  August 7, 2025 Grove Ethereum Proposal
 * @notice Onboarding of CCTP transfers to Avalanche; migration of Centrifuge JAAA and JTRSY vaults from V2 to V3; onboarding of Ethena
 * @author Grove Labs
 * Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
 * Vote  : TODO
 */
contract GroveEthereum_20250807 is GrovePayloadEthereum {

    address internal constant NEW_CENTRIFUGE_JAAA_VAULT  = 0x4880799eE5200fC58DA299e965df644fBf46780B;
    address internal constant NEW_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;

    uint256 internal constant ZERO = 0;

    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_JTRSY_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant NEW_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant NEW_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant ETHENA_MINT_RATE_LIMIT_MAX      = 250_000_000e6;
    uint256 internal constant ETHENA_MINT_RATE_LIMIT_SLOPE    = 100_000_000e6 / uint256(1 days);
    uint256 internal constant ETHENA_BURN_RATE_LIMIT_MAX      = 500_000_000e18;
    uint256 internal constant ETHENA_BURN_RATE_LIMIT_SLOPE    = 200_000_000e18 / uint256(1 days);
    uint256 internal constant ETHENA_DEPOSIT_RATE_LIMIT_MAX   = 250_000_000e18;
    uint256 internal constant ETHENA_DEPOSIT_RATE_LIMIT_SLOPE = 100_000_000e18 / uint256(1 days);

    function _execute() internal override {
        // ---------- Grove Liquidity Layer - Onboard CCTP transfers to Avalanche ----------
        // Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll  : TODO
        _onboardCctpTransfersToAvalanche();

        // ---------- Grove Liquidity Layer - Offboard old Centrifuge JAAA ----------
        // Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll  : TODO
        _offboardOldCentrifugeJaaa();

        // ---------- Grove Liquidity Layer - Offboard old Centrifuge JTRSY ----------
        // Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll  : TODO
        _offboardOldCentrifugeJtrsy();

        // ---------- Grove Liquidity Layer - Onboard new Centrifuge JAAA ----------
        // Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll  : TODO
        _onboardNewCentrifugeJaaa();

        // ---------- Grove Liquidity Layer - Onboard new Centrifuge JTRSY ----------
        // Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll  : TODO
        _onboardNewCentrifugeJtrsy();

        // ---------- Grove Liquidity Layer - Onboard Ethena ----------
        // Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        // Poll  : TODO
        _onboardEthena();
    }

    function _onboardCctpTransfersToAvalanche() internal {
        bytes32 generalCctpKey = MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 avalancheCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setUnlimitedRateLimitData(generalCctpKey);

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : avalancheCctpKey,
            maxAmount : CCTP_RATE_LIMIT_MAX,
            slope     : CCTP_RATE_LIMIT_SLOPE
        });

        MainnetController(Ethereum.ALM_CONTROLLER).setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
            bytes32(uint256(uint160(Avalanche.ALM_PROXY)))
        );
    }

    function _offboardOldCentrifugeJaaa() internal {
        bytes32 oldJaaaDepositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_DEPOSIT(),
            Ethereum.CENTRIFUGE_JAAA
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldJaaaDepositKey,
            maxAmount : ZERO,
            slope     : ZERO
        });
    }

    function _offboardOldCentrifugeJtrsy() internal {
        bytes32 oldJtrsyDepositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_DEPOSIT(),
            Ethereum.CENTRIFUGE_JTRSY
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldJtrsyDepositKey,
            maxAmount : ZERO,
            slope     : ZERO
        });
    }

    function _onboardNewCentrifugeJaaa() internal {
        _onboardERC7540Vault(
            NEW_CENTRIFUGE_JAAA_VAULT,
            NEW_JAAA_RATE_LIMIT_MAX,
            NEW_JAAA_RATE_LIMIT_SLOPE
        );
    }

    function _onboardNewCentrifugeJtrsy() internal {
        _onboardERC7540Vault(
            NEW_CENTRIFUGE_JTRSY_VAULT,
            NEW_JTRSY_RATE_LIMIT_MAX,
            NEW_JTRSY_RATE_LIMIT_SLOPE
        );
    }

    function _onboardEthena() internal {
        // USDe mint
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDE_MINT(),
            maxAmount : ETHENA_MINT_RATE_LIMIT_MAX,
            slope     : ETHENA_MINT_RATE_LIMIT_SLOPE
        });

        // USDe burn
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDE_BURN(),
            maxAmount : ETHENA_BURN_RATE_LIMIT_MAX,
            slope     : ETHENA_BURN_RATE_LIMIT_SLOPE
        });

        // sUSDe deposit (no need for withdrawal because of cooldown)
        bytes32 susdeDepositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_4626_DEPOSIT(),
            Ethereum.SUSDE
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : susdeDepositKey,
            maxAmount : ETHENA_DEPOSIT_RATE_LIMIT_MAX,
            slope     : ETHENA_DEPOSIT_RATE_LIMIT_SLOPE
        });

        // Cooldown
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setUnlimitedRateLimitData(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_SUSDE_COOLDOWN()
        );
    }

}
