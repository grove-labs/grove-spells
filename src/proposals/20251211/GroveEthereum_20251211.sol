// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  December 11, 2025 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20251211 is GrovePayloadEthereum {

    address internal constant SECURITIZE_STAC_USDC_DEPOSIT_WALLET = 0x51e4C4A356784D0B3b698BFB277C626b2b9fe178;
    address internal constant SECURITIZE_STAC_USDC_REDEEM_WALLET  = 0xbb543C77436645C8b95B64eEc39E3C0d48D4842b;
    address internal constant SECURITIZE_STAC                     = 0x51C2d74017390CbBd30550179A16A1c28F7210fc;

    address internal constant GALAXY_ARCH_CLOS_USDC_DEPOSIT_WALLET = 0x2E3A11807B94E689387f60CD4BF52A56857f2eDC;

    address internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBEEf2B5FD3D94469b7782aeBe6364E6e6FB1B709;

    address internal constant RIPPLE_RLUSD_USDC_MINT_BURN_WALLET = 0xD178a90C41ff3DcffbfDEF7De0BAF76Cbfe6a121;

    address internal constant AGORA_AUSD_USDC_MINT_WALLET = 0xfEa17E5f0e9bF5c86D5d553e2A074199F03B44E8;

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant SECURITIZE_STAC_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant SECURITIZE_STAC_USDC_DEPOSIT_SLOPE = 50_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant GALAXY_ARCH_CLOS_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant GALAXY_ARCH_CLOS_USDC_DEPOSIT_SLOPE = 50_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 20,000,000 max ; 20,000,000/day slope
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant RIPPLE_RLUSD_USDC_MINT_MAX   = 50_000_000e6;
    uint256 internal constant RIPPLE_RLUSD_USDC_MINT_SLOPE = 50_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant RIPPLE_RLUSD_USDC_BURN_MAX   = 50_000_000e6;
    uint256 internal constant RIPPLE_RLUSD_USDC_BURN_SLOPE = 50_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant AGORA_AUSD_USDC_MINT_MAX   = 50_000_000e6;
    uint256 internal constant AGORA_AUSD_USDC_MINT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {
        // [Ethereum] Onboard Securitize Tokenized AAA CLO Fund (STAC)
        //   Forum :https://forum.sky.money/t/december-11th-2025-proposed-changes-to-grove-for-upcoming-spell/27459#p-104940-h-1-ethereum-onboard-securitize-tokenized-aaa-clo-fund-stac-2
        _onboardSecuritizeStac();

        // [Ethereum] Onboard Galaxy Arch CLOs
        //   Forum : https://forum.sky.money/t/december-11th-2025-proposed-changes-to-grove-for-upcoming-spell/27459#p-104940-h-2-ethereum-onboard-galaxy-arch-clos-8
        _onboardGalaxyArchClos();

        // [Ethereum] Onboard Morpho Grove x Steakhouse High Yield Vault USDC
        //   Forum : https://forum.sky.money/t/december-11th-2025-proposed-changes-to-grove-for-upcoming-spell/27459#p-104940-h-3-ethereum-onboard-morpho-grove-x-steakhouse-high-yield-vault-usdc-14
        _onboardGroveXSteakhouseUsdcMorphoVault();

        // [Ethereum] Onboard Ripple RLUSD USDC Minting
        //   Forum : https://forum.sky.money/t/december-11th-2025-proposed-changes-to-grove-for-upcoming-spell/27459#p-104940-h-4-ethereum-onboard-ripple-rlusd-20
        _onboardRippleRlusd();

        // [Ethereum] Onboard Agora AUSD USDC Minting
        //   Forum : https://forum.sky.money/t/december-11th-2025-proposed-changes-to-grove-for-upcoming-spell/27459#p-104940-h-5-ethereum-onboard-agora-ausd-26
        _onboardAgoraAusd();
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

    function _onboardGalaxyArchClos() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            GALAXY_ARCH_CLOS_USDC_DEPOSIT_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            depositKey,
            GALAXY_ARCH_CLOS_USDC_DEPOSIT_MAX,
            GALAXY_ARCH_CLOS_USDC_DEPOSIT_SLOPE
        );
    }

    function _onboardGroveXSteakhouseUsdcMorphoVault() internal {
        _onboardERC4626Vault({
            vault        : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            depositMax   : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

    function _onboardRippleRlusd() internal {
        bytes32 mintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            RIPPLE_RLUSD_USDC_MINT_BURN_WALLET
        );

        bytes32 burnKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.RLUSD,
            RIPPLE_RLUSD_USDC_MINT_BURN_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            mintKey,
            RIPPLE_RLUSD_USDC_MINT_MAX,
            RIPPLE_RLUSD_USDC_MINT_SLOPE
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            burnKey,
            RIPPLE_RLUSD_USDC_BURN_MAX,
            RIPPLE_RLUSD_USDC_BURN_SLOPE
        );
    }

    function _onboardAgoraAusd() internal {
        bytes32 mintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            AGORA_AUSD_USDC_MINT_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            mintKey,
            AGORA_AUSD_USDC_MINT_MAX,
            AGORA_AUSD_USDC_MINT_SLOPE
        );
    }

}
