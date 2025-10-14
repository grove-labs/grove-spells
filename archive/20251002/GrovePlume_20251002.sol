// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }    from "lib/grove-address-registry/src/Plume.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { CastingHelpers }             from "src/libraries/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadPlume } from "src/libraries/GrovePayloadPlume.sol";

/**
 * @title  October 2, 2025 Grove Plume Proposal
 * @author Grove Labs
 */
contract GrovePlume_20251002 is GrovePayloadPlume {

    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_MAX   = 20_000_000e6;
    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE = 20_000_000e6 / uint256(1 days);
    uint256 internal constant PLUME_JTRSY_REDEEM_RATE_LIMIT_MAX    = 20_000_000e6;
    uint256 internal constant PLUME_JTRSY_REDEEM_RATE_LIMIT_SLOPE  = 20_000_000e6 / uint256(1 days);

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID = 1;

    function execute() external {
        // [Mainnet + Plume] Grove Liquidity Layer - Plume Deployment
        //   Forum : https://forum.sky.money/t/october-2-2025-proposed-changes-to-grove-for-upcoming-spell/27190
        //   Poll  : https://vote.sky.money/polling/QmPsHirj
        _initializeLiquidityLayer();

        // [Mainnet + Plume] Grove Liquidity Layer - Onboard Apollo ACRDX
        //   Forum : https://forum.sky.money/t/october-2-2025-proposed-changes-to-grove-for-upcoming-spell/27190
        //   Poll  : https://vote.sky.money/polling/QmTE1YTn
        _onboardCentrifugeAcrdx();

        // [Mainnet + Plume] Grove Liquidity Layer - Plume Deployment
        //   Forum : https://forum.sky.money/t/october-2-2025-proposed-changes-to-grove-for-upcoming-spell/27190
        //   Poll  : https://vote.sky.money/polling/QmPsHirj
        _onboardCentrifugeJtrsyRedemption();
    }

    function _initializeLiquidityLayer() internal {
        // Define Plume relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Plume.ALM_RELAYER;

        // Define Mainnet Centrifuge recipients
        ForeignControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new ForeignControllerInit.CentrifugeRecipient[](1);
        centrifugeRecipients[0] = ForeignControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : Plume.ALM_PROXY,
                controller : Plume.ALM_CONTROLLER,
                rateLimits : Plume.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Plume.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin      : Plume.GROVE_EXECUTOR,
                psm        : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                cctp       : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                usdc       : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER
            }),
            new ForeignControllerInit.MintRecipient[](0),
            new ForeignControllerInit.LayerZeroRecipient[](0),
            centrifugeRecipients
        );
    }

    function _onboardCentrifugeAcrdx() internal {
        _onboardERC7540Vault(
            Plume.CENTRIFUGE_ACRDX,
            PLUME_ACRDX_DEPOSIT_RATE_LIMIT_MAX,
            PLUME_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE
        );
    }

    function _onboardCentrifugeJtrsyRedemption() internal {
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            ForeignController(Plume.ALM_CONTROLLER).LIMIT_7540_REDEEM(),
            Plume.CENTRIFUGE_JTRSY
        );

        IRateLimits(Plume.ALM_RATE_LIMITS).setRateLimitData(
            withdrawKey,
            PLUME_JTRSY_REDEEM_RATE_LIMIT_MAX,
            PLUME_JTRSY_REDEEM_RATE_LIMIT_SLOPE
        );
    }

}
