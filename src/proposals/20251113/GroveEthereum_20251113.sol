// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { CastingHelpers } from "src/libraries/helpers/CastingHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  November 13, 2025 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20251113 is GrovePayloadEthereum {

    address internal constant SECURITIZE_STAC_USDC_DEPOSIT_WALLET = 0x51e4C4A356784D0B3b698BFB277C626b2b9fe178;
    address internal constant SECURITIZE_STAC_USDC_REDEEM_WALLET  = 0xbb543C77436645C8b95B64eEc39E3C0d48D4842b;
    address internal constant SECURITIZE_STAC                     = 0x51C2d74017390CbBd30550179A16A1c28F7210fc;

    address internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBEEf2B5FD3D94469b7782aeBe6364E6e6FB1B709;

    // BEFORE: 0 max ; 0 slope >> AFTER: 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant SECURITIZE_STAC_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant SECURITIZE_STAC_USDC_DEPOSIT_SLOPE = 50_000_000e6 / uint256(1 days);

    // BEFORE: 0 max ; 0 slope >> AFTER: 20,000,000 max ; 20,000,000/day slope
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    // BEFORE: 0 max ; 0 slope >> AFTER: 25,000,000 max ; 25,000,000/day slope
    uint256 internal constant CURVE_RLUSD_USDC_DEPOSIT_MAX   = 25_000_000e18;
    uint256 internal constant CURVE_RLUSD_USDC_DEPOSIT_SLOPE = 25_000_000e18 / uint256(1 days);

    // BEFORE: 0 max ; 0 slope >> AFTER: 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {
        // [Ethereum] Grove - Onboard Morpho Grove x Steakhouse High Yield Vault USDC
        //   Forum : https://forum.sky.money/t/november-13th-2025-proposed-changes-to-grove-for-upcoming-spell/27376#p-104622-ethereum-grove-onboard-morpho-grove-x-steakhouse-high-yield-vault-usdc-4
        _onboardGroveXSteakhouseUsdcMorphoVault();

        // [Ethereum] Grove - Onboard Securitize Tokenized AAA CLO Fund (STAC)
        //   Forum : https://forum.sky.money/t/november-13th-2025-proposed-changes-to-grove-for-upcoming-spell/27376#p-104622-ethereum-grove-onboard-securitize-tokenized-aaa-clo-fund-stac-3
        _onboardSecuritizeStac();

        // [Ethereum] Grove - Onboard Curve RLUSD/USDC Pool LP Deposits
        //   Forum : https://forum.sky.money/t/november-13th-2025-proposed-changes-to-grove-for-upcoming-spell/27376#p-104622-ethereum-grove-onboard-curve-rlusdusdc-pool-lp-deposits-7
        _onboardCurvePoolRlusdUsdcLP();

        // [Base] Grove - Onboard Morpho Grove x Steakhouse High Yield Vault USDC
        //   Forum : https://forum.sky.money/t/november-13th-2025-proposed-changes-to-grove-for-upcoming-spell/27376#p-104622-base-grove-onboard-morpho-grove-x-steakhouse-high-yield-vault-usdc-5
        _onboardCctpTransfersToBase();
    }

    function _onboardGroveXSteakhouseUsdcMorphoVault() internal {
        _onboardERC4626Vault({
            vault        : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            depositMax   : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

    function _onboardSecuritizeStac() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            SECURITIZE_STAC_USDC_DEPOSIT_WALLET
        );

        bytes32 redeemKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            SECURITIZE_STAC,
            SECURITIZE_STAC_USDC_REDEEM_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            depositKey,
            SECURITIZE_STAC_USDC_DEPOSIT_MAX,
            SECURITIZE_STAC_USDC_DEPOSIT_SLOPE
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setUnlimitedRateLimitData(redeemKey);
    }

    function _onboardCurvePoolRlusdUsdcLP() internal {
        _onboardCurvePoolLP({
            pool          : Ethereum.CURVE_RLUSD_USDC,
            depositMax    : CURVE_RLUSD_USDC_DEPOSIT_MAX,
            depositSlope  : CURVE_RLUSD_USDC_DEPOSIT_SLOPE,
            withdrawMax   : type(uint256).max,
            withdrawSlope : 0
        });
    }

    function _onboardCctpTransfersToBase() internal {
        MainnetController(Ethereum.ALM_CONTROLLER).setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY)
        );

        // General key rate limit for all CCTP transfers was set in the GroveEthereum_20250807 proposal

        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(domainKey, CCTP_RATE_LIMIT_MAX, CCTP_RATE_LIMIT_SLOPE);
    }

}
