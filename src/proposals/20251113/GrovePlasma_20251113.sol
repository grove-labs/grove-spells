// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { LZForwarder } from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plasma }   from "lib/grove-address-registry/src/Plasma.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadPlasma } from "src/libraries/payloads/GrovePayloadPlasma.sol";

/**
 * @title  November 13, 2025 Grove Plasma Proposal
 * @author Grove Labs
 */
contract GrovePlasma_20251113 is GrovePayloadPlasma {

    address internal constant AAVE_CORE_USDT = 0x5D72a9d9A9510Cd8cBdBA12aC62593A58930a948;

    uint256 internal constant AAVE_CORE_USDT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant AAVE_CORE_USDT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    function execute() external {
        // [Plasma] Grove - Onboard Aave v3 USDT0
        //   Forum: https://forum.sky.money/t/november-13th-2025-proposed-changes-to-grove-for-upcoming-spell/27376#p-104622-plasma-grove-onboard-aave-v3-usdt0-6
        _initializeLiquidityLayer();

        // [Plasma] Grove - Onboard Aave v3 USDT0
        //   Forum: https://forum.sky.money/t/november-13th-2025-proposed-changes-to-grove-for-upcoming-spell/27376#p-104622-plasma-grove-onboard-aave-v3-usdt0-6
        _onboardAaveCoreUsdt();
    }

    function _initializeLiquidityLayer() internal {
        // Define Plasma relayers
        address[] memory relayers = new address[](1);
        relayers[0] = Plasma.ALM_RELAYER;

        // Empty CCTPv1 mint recipients - CCTPv1 not deployed on Plasma
        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](0);

        // Empty Centrifuge recipients - Centrifuge not deployed on Plasma
        ForeignControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new ForeignControllerInit.CentrifugeRecipient[](0);

        ForeignControllerInit.LayerZeroRecipient[] memory layerZeroRecipients = new ForeignControllerInit.LayerZeroRecipient[](1);
        layerZeroRecipients[0] = ForeignControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_ETHEREUM,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : Plasma.ALM_PROXY,
                controller : Plasma.ALM_CONTROLLER,
                rateLimits : Plasma.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Plasma.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin      : Plasma.GROVE_EXECUTOR,
                cctp       : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                psm        : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                usdc       : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER
            }),
            mintRecipients,
            layerZeroRecipients,
            centrifugeRecipients
        );
    }

    function _onboardAaveCoreUsdt() internal {
        _onboardAaveToken({
            token        : AAVE_CORE_USDT,
            depositMax   : AAVE_CORE_USDT_DEPOSIT_MAX,
            depositSlope : AAVE_CORE_USDT_DEPOSIT_SLOPE
        });
    }

}
