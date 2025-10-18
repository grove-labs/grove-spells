// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/MainnetControllerInit.sol";

import { CastingHelpers } from "src/libraries/CastingHelpers.sol";
import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  October 30, 2025 Grove Ethereum Proposal
 * @author Grove Labs
 * Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
 */
contract GroveEthereum_20251030 is GrovePayloadEthereum {

    address internal constant NEW_MAINNET_CONTROLLER = 0x0D142e958B56f44C8B745A2D36F218053addF683;

    address internal constant CURVE_RLUSD_USDC = 0xD001aE433f254283FeCE51d4ACcE8c53263aa186;

    address internal constant AAVE_ATOKEN_CORE_USDC     = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address internal constant AAVE_ATOKEN_CORE_RLUSD    = 0xFa82580c16A31D0c1bC632A36F82e83EfEF3Eec0;
    address internal constant AAVE_ATOKEN_HORIZON_USDC  = 0x68215B6533c47ff9f7125aC95adf00fE4a62f79e;
    address internal constant AAVE_ATOKEN_HORIZON_RLUSD = 0xE3190143Eb552456F88464662f0c0C4aC67A77eB;

    uint256 internal constant CURVE_RLUSD_USDC_MAX_SLIPPAGE = 0.9990e18;
    uint256 internal constant CURVE_RLUSD_USDC_SWAP_MAX     = 20_000_000e18;
    uint256 internal constant CURVE_RLUSD_USDC_SWAP_SLOPE   = 100_000_000e18 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_CORE_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE = 25_000_000e6 / uint256(1 days);

    uint16 internal constant AVALANCHE_DESTINATION_CENTRIFUGE_ID = 5;
    uint16 internal constant PLUME_DESTINATION_CENTRIFUGE_ID     = 4;

    function _execute() internal override {
        // TODO: Item title
        //   Forum : TODO Forum link
        _upgradeController();

        // [Mainnet] Curve RLUSD/USDC Pool Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardCurvePoolRlusdUsdc();

        // [Mainnet] Aave Core USDC Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardAaveCoreUsdc();

        // [Mainnet] Aave Core RLUSD Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardAaveCoreRlusd();

        // [Mainnet] Aave Horizon USDC Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardAaveHorizonUsdc();

        // [Mainnet] Aave Horizon RLUSD Onboarding
        //   Forum : https://forum.sky.money/t/october-30th-2025-proposed-changes-to-grove-for-upcoming-spell/27321
        _onboardAaveHorizonRlusd();

        // TODO: Item title
        //   Forum : TODO Forum link
        _onboardSUsdePT27Nov2025Redemptions();

        // TODO: Item title
        //   Forum : TODO Forum link
        _onboardUsdePT27Nov2025Redemptions();
    }

    function _upgradeController() internal {
        address[] memory relayers = new address[](1);
        relayers[0] = Ethereum.ALM_RELAYER;

        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](1);
        mintRecipients[0] = MainnetControllerInit.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Avalanche.ALM_PROXY)
        });

        MainnetControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new MainnetControllerInit.CentrifugeRecipient[](2);
        centrifugeRecipients[0] = MainnetControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : AVALANCHE_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Avalanche.ALM_PROXY)
        });
        centrifugeRecipients[1] = MainnetControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : PLUME_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY)
        });

        MainnetControllerInit.upgradeController(
            ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : NEW_MAINNET_CONTROLLER,
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            MainnetControllerInit.ConfigAddressParams({
                freezer       : Ethereum.ALM_FREEZER,
                relayers      : relayers,
                oldController : Ethereum.ALM_CONTROLLER
            }),
            MainnetControllerInit.CheckAddressParams({
                admin      : Ethereum.GROVE_PROXY,
                proxy      : Ethereum.ALM_PROXY,
                rateLimits : Ethereum.ALM_RATE_LIMITS,
                vault      : Ethereum.ALLOCATOR_VAULT,
                psm        : Ethereum.PSM,
                daiUsds    : Ethereum.DAI_USDS,
                cctp       : Ethereum.CCTP_TOKEN_MESSENGER
            }),
            mintRecipients,
            new MainnetControllerInit.LayerZeroRecipient[](0),
            centrifugeRecipients
        );
    }

    function _onboardCurvePoolRlusdUsdc() internal {
        _onboardCurvePool({
            controller    : NEW_MAINNET_CONTROLLER,
            pool          : CURVE_RLUSD_USDC,
            maxSlippage   : CURVE_RLUSD_USDC_MAX_SLIPPAGE,
            swapMax       : CURVE_RLUSD_USDC_SWAP_MAX,
            swapSlope     : CURVE_RLUSD_USDC_SWAP_SLOPE,
            depositMax    : 0,
            depositSlope  : 0,
            withdrawMax   : 0,
            withdrawSlope : 0
        });
    }

    function _onboardAaveCoreUsdc() internal {
        _onboardAaveToken({
            token        : AAVE_ATOKEN_CORE_USDC,
            depositMax   : AAVE_ATOKEN_CORE_USDC_DEPOSIT_MAX,
            depositSlope : AAVE_ATOKEN_CORE_USDC_DEPOSIT_SLOPE
        });
    }

    function _onboardAaveCoreRlusd() internal {
        _onboardAaveToken({
            token        : AAVE_ATOKEN_CORE_RLUSD,
            depositMax   : AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_MAX,
            depositSlope : AAVE_ATOKEN_CORE_RLUSD_DEPOSIT_SLOPE
        });
    }

    function _onboardAaveHorizonUsdc() internal {
        _onboardAaveToken({
            token        : AAVE_ATOKEN_HORIZON_USDC,
            depositMax   : AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_MAX,
            depositSlope : AAVE_ATOKEN_HORIZON_USDC_DEPOSIT_SLOPE
        });
    }

    function _onboardAaveHorizonRlusd() internal {
        _onboardAaveToken({
            token        : AAVE_ATOKEN_HORIZON_RLUSD,
            depositMax   : AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_MAX,
            depositSlope : AAVE_ATOKEN_HORIZON_RLUSD_DEPOSIT_SLOPE
        });
    }

    function _onboardSUsdePT27Nov2025Redemptions() internal {
        // TODO: Implement
    }

    function _onboardUsdePT27Nov2025Redemptions() internal {
        // TODO: Implement
    }

}
