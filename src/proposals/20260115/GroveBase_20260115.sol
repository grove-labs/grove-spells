// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";
import { IRateLimits }       from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";
import { LZForwarder }     from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadBase } from "src/libraries/payloads/GrovePayloadBase.sol";


/**
 * @title  January 15, 2026 Grove Base Proposal
 * @author Grove Labs
 */
contract GroveBase_20260115 is GrovePayloadBase {

    address internal constant SECONDARY_RELAYER = 0x0000000000000000000000000000000000000000; // TODO: Replace with actual secondary relayer address

    address internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBeEf2d50B428675a1921bC6bBF4bfb9D8cF1461A;

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 50_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 50_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function execute() external {
        // TODO Item title
        //   Forum : TODO forum link
        _initializeLiquidityLayer();

        // TODO Item title
        //   Forum : TODO forum link
        _onboardGroveXSteakhouseUsdcMorphoVault();

        // TODO Item title
        //   Forum : TODO forum link
        _onboardCctpTransfersToEthereum();
    }

    function _initializeLiquidityLayer() internal {
        // Define Base relayers
        address[] memory relayers = new address[](2);
        relayers[0] = Base.ALM_RELAYER;
        relayers[1] = SECONDARY_RELAYER;


        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](1);
        mintRecipients[0] = ForeignControllerInit.MintRecipient({
            domain        : CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.LayerZeroRecipient[] memory layerZeroRecipients = new ForeignControllerInit.LayerZeroRecipient[](1);
        layerZeroRecipients[0] = ForeignControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_ETHEREUM,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new ForeignControllerInit.CentrifugeRecipient[](1);
        centrifugeRecipients[0] = ForeignControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : Base.ALM_PROXY,
                controller : Base.ALM_CONTROLLER, // TODO make sure it's redeployed to post-audit version
                rateLimits : Base.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Base.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin : Base.GROVE_EXECUTOR,
                cctp  : Base.CCTP_TOKEN_MESSENGER, // TODO: Replace with CCTP_TOKEN_MESSENGER_V2
                psm   : Base.PSM3,
                usdc  : Base.USDC
            }),
            mintRecipients,
            layerZeroRecipients,
            centrifugeRecipients
        );
    }

    function _onboardGroveXSteakhouseUsdcMorphoVault() internal {
        _onboardERC4626Vault({
            vault        : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            depositMax   : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

    function _onboardCctpTransfersToEthereum() internal {
        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        IRateLimits(Base.ALM_RATE_LIMITS).setRateLimitData(domainKey, CCTP_RATE_LIMIT_MAX, CCTP_RATE_LIMIT_SLOPE);
        IRateLimits(Base.ALM_RATE_LIMITS).setUnlimitedRateLimitData(ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP());
    }

}

