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
 * Forum               : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
 * Vote (USDe & sUSDe) : https://vote.sky.money/polling/QmNsimEt
 * Vote (CCTP)         : https://vote.sky.money/polling/QmX2CAp2
 */
contract GroveEthereum_20250807 is GrovePayloadEthereum {

    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant ETHENA_MINT_RATE_LIMIT_MAX      = 250_000_000e6;
    uint256 internal constant ETHENA_MINT_RATE_LIMIT_SLOPE    = 100_000_000e6 / uint256(1 days);
    uint256 internal constant ETHENA_BURN_RATE_LIMIT_MAX      = 500_000_000e18;
    uint256 internal constant ETHENA_BURN_RATE_LIMIT_SLOPE    = 200_000_000e18 / uint256(1 days);
    uint256 internal constant ETHENA_DEPOSIT_RATE_LIMIT_MAX   = 250_000_000e18;
    uint256 internal constant ETHENA_DEPOSIT_RATE_LIMIT_SLOPE = 100_000_000e18 / uint256(1 days);

    constructor() {
        PAYLOAD_AVALANCHE = 0x6AC0865E7fcAd8B89850b83A709eEC57569f919f;
    }

    function _execute() internal override {
        // [Mainnet and Avalanche] Deploy Grove Liquidity Layer on Avalanche
        //   Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        //   Poll  : https://vote.sky.money/polling/QmX2CAp2
        _onboardCctpTransfersToAvalanche();

        // [Mainnet] Onboard Ethena USDe and sUSDe to the GLL
        //   Forum : https://forum.sky.money/t/august-7-2025-proposed-changes-to-grove-for-upcoming-spell/26883
        //   Poll  : https://vote.sky.money/polling/QmNsimEt
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
