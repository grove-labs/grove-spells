// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
// import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

// import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

// import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  January 29, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260129 is GrovePayloadEthereum {

    address internal constant AUSD  = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address internal constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;

    address internal constant OLD_AGORA_AUSD_MINT_WALLET   = 0xfEa17E5f0e9bF5c86D5d553e2A074199F03B44E8;
    address internal constant NEW_AGORA_AUSD_MINT_WALLET   = 0x748b66a6b3666311F370218Bc2819c0bEe13677e;
    address internal constant NEW_AGORA_AUSD_REDEEM_WALLET = 0xab8306d9FeFBE8183c3C59cA897A2E0Eb5beFE67;

    address internal constant CURVE_AUSD_USDC_POOL = 0xE79C1C7E24755574438A26D5e062Ad2626C04662;

    address internal constant UNISWAP_V3_AUSD_USDC_POOL = 0xbAFeAd7c60Ea473758ED6c6021505E8BBd7e8E5d;

    address internal constant CURVE_PYUSD_USDS_POOL = 0xA632D59b9B804a956BfaA9b48Af3A1b74808FC1f;

    address internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT = 0xBeefF08dF54897e7544aB01d0e86f013DA354111;

    address internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT = 0xd8A6511979D9C5D387c819E9F8ED9F3a5C6c5379;

    address internal constant GROVE_CORE_RELAYER_OPERATOR      = 0x4364D17B578b0eD1c42Be9075D774D1d6AeAFe96;
    address internal constant GROVE_SECONDARY_RELAYER_OPERATOR = 0x9187807e07112359C481870feB58f0c117a29179;

    // AUSD RATE LIMITS

    // CURVE AUSD/USDC RATE LIMITS

    // UNISWAP V3 AUSD/USDC RATE LIMITS

    // CURVE PYUSD/USDS RATE LIMITS

    // BEFORE :          0 max ;          0/day slope ;    0 max exchange rate
    // AFTER  : 20,000,000 max ; 20,000,000/day slope ; 2e24 max exchange rate ( 2e6 assets / 1e18 share unit * 1e36 exchange rate precision )
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_MAX          = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_SLOPE        = 20_000_000e6 / uint256(1 days);
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_SHARE_UNIT           = 1e18;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_MAX_ASSETS_PER_SHARE = 2e6;

    // STEAKHOUSE PYUSD MORPHO VAULT RATE LIMITS

    function _execute() internal override {
        // [Mainnet] Re-Onboard Agora AUSD Mint Redeem
        // Forum : https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608#p-105385-h-1-mainnet-re-onboard-agora-ausd-mint-redeem-2
        _reOnboardAgoraAusdMintRedeem();

        // [Mainnet] Onboard Curve AUSD/USDC Swaps & LP
        // Forum : https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608#p-105385-h-2-mainnet-onboard-curve-ausdusdc-swaps-lp-8
        _onboardCurveAusdUsdcSwapsAndLp();

        // [Mainnet] Onboard Uniswap v3 AUSD/USDC Swaps & LP
        // Forum : https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608#p-105385-h-3-mainnet-onboard-uniswap-v3-ausdusdc-swaps-lp-14
        _onboardUniswapV3AusdUsdcSwapsAndLp();

        // [Mainnet] Onboard Curve PYUSD/USDS Swaps
        // Forum : https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608#p-105385-h-4-mainnet-onboard-curve-pyusdusds-swaps-20
        _onboardCurvePyusdUsdsSwaps();

        // [Mainnet] Onboard Grove x Steakhouse USDC Morpho Vault
        // Forum : https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608#p-105385-h-5-mainnet-grove-x-steakhouse-usdc-morpho-vault-v2-26
        _onboardGroveXSteakhouseUsdcMorphoVault();

        // [Mainnet] Onboard Steakhouse PYUSD Morpho Vault
        // Forum : https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608#p-105385-h-6-mainnet-onboard-steakhouse-pyusd-morpho-vault-32
        _onboardSteakhousePyusdMorphoVault();

        // [Mainnet] Onboard Relayers for Grove Liquidity Layer
        // Forum : https://forum.sky.money/t/january-29-2026-proposed-changes-to-grove-for-upcoming-spell/27608#p-105385-h-7-mainnet-onboard-relayers-for-grove-liquidity-layer-38
        _onboardRelayers();
    }

    function _reOnboardAgoraAusdMintRedeem() internal {
        // TODO: Implement
    }

    function _onboardCurveAusdUsdcSwapsAndLp() internal {
        // TODO: Implement
    }

    function _onboardUniswapV3AusdUsdcSwapsAndLp() internal {
        // TODO: Implement
    }

    function _onboardCurvePyusdUsdsSwaps() internal {
        // TODO: Implement
    }

    function _onboardGroveXSteakhouseUsdcMorphoVault() internal {
        _onboardERC4626Vault({
            vault             : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT,
            depositMax        : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope      : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_SLOPE,
            shareUnit         : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_SHARE_UNIT,
            maxAssetsPerShare : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_MAX_ASSETS_PER_SHARE
        });
    }

    function _onboardSteakhousePyusdMorphoVault() internal {
        // TODO: Implement
    }

    function _onboardRelayers() internal {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        controller.grantRole(controller.RELAYER(), GROVE_CORE_RELAYER_OPERATOR);
        controller.grantRole(controller.RELAYER(), GROVE_SECONDARY_RELAYER_OPERATOR);
    }

}
