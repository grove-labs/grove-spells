// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  October 30, 2025 Grove Ethereum Proposal
 * @author Grove Labs
 * Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
 */
contract GroveEthereum_20251030 is GrovePayloadEthereum {

    address internal constant CURVE_RLUSDUSDC = 0xD001aE433f254283FeCE51d4ACcE8c53263aa186;

    address internal constant AAVE_ATOKEN_CORE_USDC     = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address internal constant AAVE_ATOKEN_CORE_RLUSD    = 0xFa82580c16A31D0c1bC632A36F82e83EfEF3Eec0;
    address internal constant AAVE_ATOKEN_HORIZON_USDC  = 0x68215B6533c47ff9f7125aC95adf00fE4a62f79e;
    address internal constant AAVE_ATOKEN_HORIZON_RLUSD = 0xE3190143Eb552456F88464662f0c0C4aC67A77eB;

    uint256 internal constant CURVE_RLUSDUSDC_MAX_SLIPPAGE = 0.9990e18;
    uint256 internal constant CURVE_RLUSDUSDC_SWAP_MAX     = 20_000_000e18;
    uint256 internal constant CURVE_RLUSDUSDC_SWAP_SLOPE   = 100_000_000e18 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_CORE_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    function _execute() internal override {
        // [Mainnet] Curve RLUSD/USDC Pool Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardCurvePool({
            controller    : Ethereum.ALM_CONTROLLER,
            pool          : CURVE_RLUSDUSDC,
            maxSlippage   : CURVE_RLUSDUSDC_MAX_SLIPPAGE,
            swapMax       : CURVE_RLUSDUSDC_SWAP_MAX,
            swapSlope     : CURVE_RLUSDUSDC_SWAP_SLOPE,
            depositMax    : 0,
            depositSlope  : 0,
            withdrawMax   : 0,
            withdrawSlope : 0
        });

        // [Mainnet] Aave Core USDC Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardAaveToken({
            token        : AAVE_ATOKEN_CORE_USDC,
            depositMax   : AAVE_ATOKEN_CORE_USDC_DEPOSIT_MAX,
            depositSlope : AAVE_ATOKEN_CORE_USDC_DEPOSIT_SLOPE
        });

        // [Mainnet] Aave Core RLUSD Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardAaveToken({
            token        : AAVE_ATOKEN_CORE_RLUSD,
            depositMax   : AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_MAX,
            depositSlope : AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_SLOPE
        });

        // [Mainnet] Aave Horizon USDC Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardAaveToken({
            token        : AAVE_ATOKEN_HORIZON_USDC,
            depositMax   : AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_MAX,
            depositSlope : AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_SLOPE
        });

        // [Mainnet] Aave Horizon RLUSD Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardAaveToken({
            token        : AAVE_ATOKEN_HORIZON_RLUSD,
            depositMax   : AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX,
            depositSlope : AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE
        });
    }

}
