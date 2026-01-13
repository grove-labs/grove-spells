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
        // TODO: Implement
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
