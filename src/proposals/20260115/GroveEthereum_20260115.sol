// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { LZForwarder }   from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  January 15, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260115 is GrovePayloadEthereum {

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {

        // TODO Item title
        //   Forum : TODO forum link
        _initializeBaseLiquidityLayer();

        // TODO Item title
        //   Forum : TODO forum link
        _onboardCctpTransfersToBase();
    }

    function _initializeBaseLiquidityLayer() internal {
        MainnetController(Ethereum.ALM_CONTROLLER).setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY)
        );

        // NOTE In case of complexity comp score going over the limit, remove this item and flip the testing flag to false in CommonSpellTests.sol
        MainnetController(Ethereum.ALM_CONTROLLER).setCentrifugeRecipient(
            GroveLiquidityLayerHelpers.BASE_DESTINATION_CENTRIFUGE_ID,
            CastingHelpers.addressToCentrifugeRecipient(Base.ALM_PROXY)
        );

        // NOTE In case of complexity comp score going over the limit, remove this item and flip the testing flag to false in CommonSpellTests.sol
        MainnetController(Ethereum.ALM_CONTROLLER).setLayerZeroRecipient(
            LZForwarder.ENDPOINT_ID_BASE,
            CastingHelpers.addressToLayerZeroRecipient(Base.ALM_PROXY)
        );
    }

    function _onboardCctpTransfersToBase() internal {
        // General key rate limit for all CCTP transfers was set in the GroveEthereum_20250807 proposal

        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(domainKey, CCTP_RATE_LIMIT_MAX, CCTP_RATE_LIMIT_SLOPE);
    }

}
