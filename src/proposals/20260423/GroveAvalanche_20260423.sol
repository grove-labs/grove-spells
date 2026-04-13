// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { LZForwarder }   from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { IExecutor } from "lib/grove-gov-relay/src/interfaces/IExecutor.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadAvalanche } from "src/libraries/payloads/GrovePayloadAvalanche.sol";

/**
 * @title  April 23, 2026 Grove Avalanche Proposal
 * @author Grove Labs
 */
contract GroveAvalanche_20260423 is GrovePayloadAvalanche {

    address internal constant NEW_AVALANCHE_CONTROLLER = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;

    address internal constant ALM_RELAYER_2 = 0x9187807e07112359C481870feB58f0c117a29179;

    address internal constant USDS_OFT = 0x4fec40719fD9a8AE3F8E20531669DEC5962D2619;

    address internal constant CURVE_USDS_USDC_POOL = 0xA9d7d3D7e68a0cae89FB33c736199172f405C8D3;

    function execute() external {
        // [Avalanche] Upgrade Controller & Governance Relay to LayerZero V2
        //   Forum : https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829#p-106126-h-4-avalanche-upgrade-controller-governance-relay-to-layerzero-v2-20
        _upgradeController();

        // [Avalanche] Onboard USDS SkyLink Transfers to Ethereum
        //   Forum : https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829#p-106126-h-5-avalanche-onboard-usds-skylink-transfers-to-ethereum-26
        _onboardUsdsSkyLinkTransfersToEthereum();

        // [Avalanche] Increase CCTP USDC Transfer to Ethereum Rate Limit
        //   Forum : https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829#p-106126-h-6-avalanche-increase-cctp-usdc-transfer-to-ethereum-rate-limit-32
        _increaseCctpUsdcTransferToEthereumRateLimit();

        // [Avalanche] Onboard USDS/USDC Curve Stableswap Swaps & LP
        //   Forum : https://forum.skyeco.com/t/april-23-2026-proposed-changes-to-grove-for-upcoming-spell/27829#p-106126-h-7-avalanche-onboard-usdsusdc-curve-stableswap-swaps-lp-38
        _onboardCurveUsdsUsdcPool();
    }

    function _upgradeController() internal {
        address[] memory relayers = new address[](2);
        relayers[0] = Avalanche.ALM_RELAYER;
        relayers[1] = ALM_RELAYER_2;

        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](1);
        mintRecipients[0] = ForeignControllerInit.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.LayerZeroRecipient[] memory layerZeroRecipients = new ForeignControllerInit.LayerZeroRecipient[](1);
        layerZeroRecipients[0] = ForeignControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_ETHEREUM,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new ForeignControllerInit.CentrifugeRecipient[](1);
        centrifugeRecipients[0] = ForeignControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : 1, // ETHEREUM_DESTINATION_CENTRIFUGE_ID
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY)
        });

        address avalanchePlaceholderPsmAddress = address(ForeignController(Avalanche.ALM_CONTROLLER).psm());

        ForeignControllerInit.upgradeController(
            ControllerInstance({
                almProxy   : Avalanche.ALM_PROXY,
                controller : NEW_AVALANCHE_CONTROLLER,
                rateLimits : Avalanche.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Avalanche.ALM_FREEZER,
                relayers      : relayers,
                oldController : Avalanche.ALM_CONTROLLER
            }),
            ForeignControllerInit.CheckAddressParams({
                admin                    : Avalanche.GROVE_EXECUTOR,
                psm                      : avalanchePlaceholderPsmAddress,
                cctp                     : Avalanche.CCTP_TOKEN_MESSENGER_V2,
                usdc                     : Avalanche.USDC,
                pendleRouter             : address(0xDeaDBeef), // Deliberately empty stub address; pendle not deployed on Avalanche
                uniswapV3Router          : Avalanche.UNISWAP_V3_SWAP_ROUTER_02,
                uniswapV3PositionManager : Avalanche.UNISWAP_V3_POSITION_MANAGER
            }),
            mintRecipients,
            layerZeroRecipients,
            centrifugeRecipients
        );
    }

    function _onboardUsdsSkyLinkTransfersToEthereum() internal {
        // LayerZero recipient for Ethereum is configured in _upgradeController()
        bytes32 lzTransferKey = keccak256(abi.encode(
            ForeignController(NEW_AVALANCHE_CONTROLLER).LIMIT_LAYERZERO_TRANSFER(),
            USDS_OFT,
            LZForwarder.ENDPOINT_ID_ETHEREUM
        ));

        IRateLimits(Avalanche.ALM_RATE_LIMITS).setRateLimitData({
            key       : lzTransferKey,
            maxAmount : 20_000_000e18,                  // BEFORE: 0
            slope     : 20_000_000e18 / uint256(1 days) // BEFORE: 0
        });
    }

    function _increaseCctpUsdcTransferToEthereumRateLimit() internal {
        bytes32 domainKey = RateLimitHelpers.makeDomainKey({
            key    : ForeignController(NEW_AVALANCHE_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            domain : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        });

        IRateLimits(Avalanche.ALM_RATE_LIMITS).setUnlimitedRateLimitData(domainKey);
    }

    function _onboardCurveUsdsUsdcPool() internal {
        GroveLiquidityLayerHelpers.onboardCurvePool({
            controller    : NEW_AVALANCHE_CONTROLLER,
            rateLimits    : Avalanche.ALM_RATE_LIMITS,
            pool          : CURVE_USDS_USDC_POOL,
            maxSlippage   : 0.999e18,                         // BEFORE: 0
            swapMax       : 5_000_000e18,                     // BEFORE: 0
            swapSlope     : 100_000_000e18 / uint256(1 days), // BEFORE: 0
            depositMax    : 50_000_000e18,                    // BEFORE: 0
            depositSlope  : 50_000_000e18 / uint256(1 days),  // BEFORE: 0
            withdrawMax   : type(uint256).max,                // BEFORE: 0
            withdrawSlope : 0                                 // BEFORE: 0
        });
    }

}
