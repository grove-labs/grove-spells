// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }    from "lib/grove-address-registry/src/Plume.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { CastingHelpers }             from "src/libraries/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadPlume } from "src/libraries/GrovePayloadPlume.sol";

contract GrovePlume_20250918 is GrovePayloadPlume {

    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_MAX               = 20_000_000e6;
    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE             = 20_000_000e6 / uint256(1 days);
    uint256 internal constant JTRSY_ACRDX_DEPOSIT_RATE_LIMIT_MAX               = 20_000_000e6;
    uint256 internal constant JTRSY_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE             = 20_000_000e6 / uint256(1 days);
    uint256 internal constant JTRSY_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 20_000_000e6;
    uint256 internal constant JTRSY_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID = 1;

    function execute() external {
        // TODO: Add item title
        //   Forum : https://forum.sky.money/t/october-2-2025-proposed-changes-to-grove-for-upcoming-spell/27190
        //   Poll  : TODO: Add link
        _initializeLiquidityLayer();

        // TODO: Add item title
        //   Forum : https://forum.sky.money/t/october-2-2025-proposed-changes-to-grove-for-upcoming-spell/27190
        //   Poll  : TODO: Add link
        _onboardCentrifugeAcrdx();

        // TODO: Add item title
        //   Forum : https://forum.sky.money/t/october-2-2025-proposed-changes-to-grove-for-upcoming-spell/27190
        //   Poll  : TODO: Add link
        _onboardCentrifugeJtrsyRedemption();
    }

    function _initializeLiquidityLayer() internal {
        // Define Plume relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Plume.ALM_RELAYER;

        // Define Mainnet CCTP mint recipients
        ForeignControllerInit.MintRecipient[] memory cctpRecipients = new ForeignControllerInit.MintRecipient[](1);
        cctpRecipients[0] = ForeignControllerInit.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
        });

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
            cctpRecipients,
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
        IRateLimits(Plume.ALM_RATE_LIMITS).setUnlimitedRateLimitData(RateLimitHelpers.makeAssetKey(
            ForeignController(Plume.ALM_CONTROLLER).LIMIT_7540_REDEEM(),
            Plume.CENTRIFUGE_JTRSY
        ));
    }
}
