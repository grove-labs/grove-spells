// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { UniswapV3Helpers } from "src/libraries/helpers/UniswapV3Helpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  January 29, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260129 is GrovePayloadEthereum {

    /******************************************************************************************************************/
    /*** [Mainnet] Re-Onboard Agora AUSD Mint Redeem                                                                ***/
    /******************************************************************************************************************/

    address internal constant AUSD                         = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address internal constant OLD_AGORA_AUSD_MINT_WALLET   = 0xfEa17E5f0e9bF5c86D5d553e2A074199F03B44E8;
    address internal constant NEW_AGORA_AUSD_MINT_WALLET   = 0x748b66a6b3666311F370218Bc2819c0bEe13677e;
    address internal constant NEW_AGORA_AUSD_REDEEM_WALLET = 0xab8306d9FeFBE8183c3C59cA897A2E0Eb5beFE67;

    // BEFORE : 50,000,000 max ; 50,000,000/day slope
    // AFTER  :          0 max ;          0/day slope
    uint256 internal constant OLD_AGORA_AUSD_USDC_MINT_MAX   = 0;
    uint256 internal constant OLD_AGORA_AUSD_USDC_MINT_SLOPE = 0;

    // BEFORE :          0 max ;           0/day slope
    // AFTER  : 10,000,000 max ; 100,000,000/day slope
    uint256 internal constant NEW_AGORA_AUSD_USDC_MINT_MAX   = 10_000_000e6;
    uint256 internal constant NEW_AGORA_AUSD_USDC_MINT_SLOPE = 100_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;           0/day slope
    // AFTER  : 10,000,000 max ; 100,000,000/day slope
    uint256 internal constant NEW_AGORA_AUSD_USDC_REDEEM_MAX   = 10_000_000e6;
    uint256 internal constant NEW_AGORA_AUSD_USDC_REDEEM_SLOPE = 100_000_000e6 / uint256(1 days);

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Curve AUSD/USDC Swaps & LP                                                               ***/
    /******************************************************************************************************************/

    address internal constant CURVE_AUSD_USDC_POOL = 0xE79C1C7E24755574438A26D5e062Ad2626C04662;

    // BEFORE :          0 max ;           0/day slope ; 0     max slippage
    // AFTER  : 5,000,000 max  ; 100,000,000/day slope ; 0.999 max slippage (allowing 0.1% slippage)
    uint256 internal constant CURVE_AUSD_USDC_SWAP_MAX     = 5_000_000e18;
    uint256 internal constant CURVE_AUSD_USDC_SWAP_SLOPE   = 100_000_000e18 / uint256(1 days);
    uint256 internal constant CURVE_AUSD_USDC_MAX_SLIPPAGE = 0.999e18;

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 25,000,000 max ; 25,000,000/day slope
    uint256 internal constant CURVE_AUSD_USDC_DEPOSIT_MAX   = 25_000_000e18;
    uint256 internal constant CURVE_AUSD_USDC_DEPOSIT_SLOPE = 25_000_000e18 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  :  unlimited max ;          0/day slope
    uint256 internal constant CURVE_AUSD_USDC_WITHDRAW_MAX   = type(uint256).max;
    uint256 internal constant CURVE_AUSD_USDC_WITHDRAW_SLOPE = 0;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Uniswap v3 AUSD/USDC Swaps & LP                                                          ***/
    /******************************************************************************************************************/

    address internal constant UNISWAP_V3_AUSD_USDC_POOL = 0xbAFeAd7c60Ea473758ED6c6021505E8BBd7e8E5d;

    // BEFORE : 0     max slippage ; 0   twap seconds ago ; 0   max tick delta
    // AFTER  : 0.999 max slippage ; 600 twap seconds ago ; 200 max tick delta
    uint256 internal constant UNISWAP_V3_AUSD_USDC_MAX_SLIPPAGE     = 0.999e18;
    uint32  internal constant UNISWAP_V3_AUSD_USDC_TWAP_SECONDS_AGO = 600;
    uint24  internal constant UNISWAP_V3_AUSD_USDC_MAX_TICK_DELTA   = 200;

    // BEFORE :   0 lower tick bound ;   0 upper tick bound
    // AFTER  : -10 lower tick bound ; +10 upper tick bound
    int24 internal constant UNISWAP_V3_AUSD_USDC_LOWER_TICK_BOUND = -10;
    int24 internal constant UNISWAP_V3_AUSD_USDC_UPPER_TICK_BOUND =  10;

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 5,000,000 max ; 100,000,000/day slope
    uint256 internal constant UNISWAP_V3_AUSD_USDC_SWAP_AUSD_MAX   = 5_000_000e6;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_SWAP_AUSD_SLOPE = 100_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 5,000,000 max ; 100,000,000/day slope
    uint256 internal constant UNISWAP_V3_AUSD_USDC_SWAP_USDC_MAX   = 5_000_000e6;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_SWAP_USDC_SLOPE = 100_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 25,000,000 max ; 25,000,000/day slope
    uint256 internal constant UNISWAP_V3_AUSD_USDC_DEPOSIT_AUSD_MAX   = 25_000_000e6;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_DEPOSIT_AUSD_SLOPE = 25_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 25,000,000 max ; 25,000,000/day slope
    uint256 internal constant UNISWAP_V3_AUSD_USDC_DEPOSIT_USDC_MAX   = 25_000_000e6;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_DEPOSIT_USDC_SLOPE = 25_000_000e6 / uint256(1 days);

    // BEFORE :         0 max ;          0/day slope
    // AFTER  : unlimited max ;          0/day slope
    uint256 internal constant UNISWAP_V3_AUSD_USDC_WITHDRAW_AUSD_MAX   = type(uint256).max;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_WITHDRAW_AUSD_SLOPE = 0;

    // BEFORE :         0 max ;          0/day slope
    // AFTER  : unlimited max ;          0/day slope
    uint256 internal constant UNISWAP_V3_AUSD_USDC_WITHDRAW_USDC_MAX   = type(uint256).max;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_WITHDRAW_USDC_SLOPE = 0;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Curve PYUSD/USDS Swaps                                                                   ***/
    /******************************************************************************************************************/

    address internal constant CURVE_PYUSD_USDS_POOL = 0xA632D59b9B804a956BfaA9b48Af3A1b74808FC1f;

    // BEFORE :          0 max ;           0/day slope ; 0     max slippage
    // AFTER  : 5,000,000 max  ; 100,000,000/day slope ; 0.999 max slippage (allowing 0.1% slippage)
    uint256 internal constant CURVE_PYUSD_USDS_SWAP_MAX     = 5_000_000e18;
    uint256 internal constant CURVE_PYUSD_USDS_SWAP_SLOPE   = 100_000_000e18 / uint256(1 days);
    uint256 internal constant CURVE_PYUSD_USDS_MAX_SLIPPAGE = 0.999e18;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Grove x Steakhouse USDC Morpho Vault                                                     ***/
    /******************************************************************************************************************/

    address internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT = 0xBeefF08dF54897e7544aB01d0e86f013DA354111;

    // BEFORE :          0 max ;          0/day slope ;    0 max exchange rate
    // AFTER  : 20,000,000 max ; 20,000,000/day slope ; 2e24 max exchange rate ( 2e6 assets / 1e18 share unit * 1e36 exchange rate precision )
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_MAX          = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_SLOPE        = 20_000_000e6 / uint256(1 days);
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_SHARE_UNIT           = 1e18;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_MAX_ASSETS_PER_SHARE = 2e6;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Steakhouse PYUSD Morpho Vault                                                            ***/
    /******************************************************************************************************************/

    address internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT = 0xd8A6511979D9C5D387c819E9F8ED9F3a5C6c5379;

    // BEFORE :          0 max ;          0/day slope ;    0 max exchange rate
    // AFTER  : 20,000,000 max ; 20,000,000/day slope ; 4e24 max exchange rate ( 4e6 assets / 1e18 share unit * 1e36 exchange rate precision )
    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_DEPOSIT_MAX          = 20_000_000e6;
    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_DEPOSIT_SLOPE        = 20_000_000e6 / uint256(1 days);
    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_SHARE_UNIT           = 1e18;
    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_MAX_ASSETS_PER_SHARE = 4e6;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Relayers for Grove Liquidity Layer                                                       ***/
    /******************************************************************************************************************/

    address internal constant GROVE_CORE_RELAYER_OPERATOR      = 0x4364D17B578b0eD1c42Be9075D774D1d6AeAFe96;
    address internal constant GROVE_SECONDARY_RELAYER_OPERATOR = 0x9187807e07112359C481870feB58f0c117a29179;

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
        bytes32 oldMintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            OLD_AGORA_AUSD_MINT_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldMintKey,
            maxAmount : OLD_AGORA_AUSD_USDC_MINT_MAX,
            slope     : OLD_AGORA_AUSD_USDC_MINT_SLOPE
        });

        bytes32 newMintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            NEW_AGORA_AUSD_MINT_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : newMintKey,
            maxAmount : NEW_AGORA_AUSD_USDC_MINT_MAX,
            slope     : NEW_AGORA_AUSD_USDC_MINT_SLOPE
        });

        bytes32 newRedeemKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            AUSD,
            NEW_AGORA_AUSD_REDEEM_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : newRedeemKey,
            maxAmount : NEW_AGORA_AUSD_USDC_REDEEM_MAX,
            slope     : NEW_AGORA_AUSD_USDC_REDEEM_SLOPE
        });
    }

    function _onboardCurveAusdUsdcSwapsAndLp() internal {
        _onboardCurvePool({
            controller    : Ethereum.ALM_CONTROLLER,
            pool          : CURVE_AUSD_USDC_POOL,
            maxSlippage   : CURVE_AUSD_USDC_MAX_SLIPPAGE,
            swapMax       : CURVE_AUSD_USDC_SWAP_MAX,
            swapSlope     : CURVE_AUSD_USDC_SWAP_SLOPE,
            depositMax    : CURVE_AUSD_USDC_DEPOSIT_MAX,
            depositSlope  : CURVE_AUSD_USDC_DEPOSIT_SLOPE,
            withdrawMax   : CURVE_AUSD_USDC_WITHDRAW_MAX,
            withdrawSlope : CURVE_AUSD_USDC_WITHDRAW_SLOPE
        });
    }

    function _onboardUniswapV3AusdUsdcSwapsAndLp() internal {
        _onboardUniswapV3Pool({
            controller : Ethereum.ALM_CONTROLLER,
            pool       : UNISWAP_V3_AUSD_USDC_POOL,
            poolParams : UniswapV3Helpers.UniswapV3PoolParams({
                maxSlippage    : UNISWAP_V3_AUSD_USDC_MAX_SLIPPAGE,
                maxTickDelta   : UNISWAP_V3_AUSD_USDC_MAX_TICK_DELTA,
                twapSecondsAgo : UNISWAP_V3_AUSD_USDC_TWAP_SECONDS_AGO,
                lowerTickBound : UNISWAP_V3_AUSD_USDC_LOWER_TICK_BOUND,
                upperTickBound : UNISWAP_V3_AUSD_USDC_UPPER_TICK_BOUND
            }),
            token0Params : UniswapV3Helpers.UniswapV3TokenParams({
                swapMax       : UNISWAP_V3_AUSD_USDC_SWAP_AUSD_MAX,
                swapSlope     : UNISWAP_V3_AUSD_USDC_SWAP_AUSD_SLOPE,
                depositMax    : UNISWAP_V3_AUSD_USDC_DEPOSIT_AUSD_MAX,
                depositSlope  : UNISWAP_V3_AUSD_USDC_DEPOSIT_AUSD_SLOPE,
                withdrawMax   : UNISWAP_V3_AUSD_USDC_WITHDRAW_AUSD_MAX,
                withdrawSlope : UNISWAP_V3_AUSD_USDC_WITHDRAW_AUSD_SLOPE
            }),
            token1Params : UniswapV3Helpers.UniswapV3TokenParams({
                swapMax       : UNISWAP_V3_AUSD_USDC_SWAP_USDC_MAX,
                swapSlope     : UNISWAP_V3_AUSD_USDC_SWAP_USDC_SLOPE,
                depositMax    : UNISWAP_V3_AUSD_USDC_DEPOSIT_USDC_MAX,
                depositSlope  : UNISWAP_V3_AUSD_USDC_DEPOSIT_USDC_SLOPE,
                withdrawMax   : UNISWAP_V3_AUSD_USDC_WITHDRAW_USDC_MAX,
                withdrawSlope : UNISWAP_V3_AUSD_USDC_WITHDRAW_USDC_SLOPE
            })
        });
    }

    function _onboardCurvePyusdUsdsSwaps() internal {
        _onboardCurvePool({
            controller    : Ethereum.ALM_CONTROLLER,
            pool          : CURVE_PYUSD_USDS_POOL,
            maxSlippage   : CURVE_PYUSD_USDS_MAX_SLIPPAGE,
            swapMax       : CURVE_PYUSD_USDS_SWAP_MAX,
            swapSlope     : CURVE_PYUSD_USDS_SWAP_SLOPE,
            depositMax    : 0,
            depositSlope  : 0,
            withdrawMax   : 0,
            withdrawSlope : 0
        });
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
        _onboardERC4626Vault({
            vault             : STEAKHOUSE_PYUSD_MORPHO_VAULT,
            depositMax        : STEAKHOUSE_PYUSD_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope      : STEAKHOUSE_PYUSD_MORPHO_VAULT_DEPOSIT_SLOPE,
            shareUnit         : STEAKHOUSE_PYUSD_MORPHO_VAULT_SHARE_UNIT,
            maxAssetsPerShare : STEAKHOUSE_PYUSD_MORPHO_VAULT_MAX_ASSETS_PER_SHARE
        });
    }

    function _onboardRelayers() internal {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        controller.grantRole(controller.RELAYER(), GROVE_CORE_RELAYER_OPERATOR);
        controller.grantRole(controller.RELAYER(), GROVE_SECONDARY_RELAYER_OPERATOR);
    }

}
