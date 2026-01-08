// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";
import { IRateLimits }       from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { CastingHelpers } from "src/libraries/helpers/CastingHelpers.sol";

import { GrovePayloadBase } from "src/libraries/payloads/GrovePayloadBase.sol";


/**
 * @title  January 15, 2026 Grove Base Proposal
 * @author Grove Labs
 */
contract GroveBase_20260115 is GrovePayloadBase {

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 20,000,000 max ; 20,000,000/day slope
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function execute() external {
        // [Base] Onboard Grove Liquidity Layer and CCTP for Base
        //   Forum : https://forum.sky.money/t/january-15th-2026-proposed-changes-to-grove-for-upcoming-spell/27570#p-105288-h-1-base-onboard-grove-liquidity-layer-and-cctp-for-base-2
        _initializeLiquidityLayer();

        // [Base] Onboard Morpho Grove x Steakhouse High Yield Vault USDC
        //   Forum : https://forum.sky.money/t/january-15th-2026-proposed-changes-to-grove-for-upcoming-spell/27570#p-105288-h-2-base-onboard-morpho-grove-x-steakhouse-high-yield-vault-usdc-8
        _onboardGroveXSteakhouseUsdcMorphoVault();

        // [Base] Onboard Grove Liquidity Layer and CCTP for Base
        //   Forum : https://forum.sky.money/t/january-15th-2026-proposed-changes-to-grove-for-upcoming-spell/27570#p-105288-h-1-base-onboard-grove-liquidity-layer-and-cctp-for-base-2
        _onboardCctpTransfersToEthereum();
    }

    function _initializeLiquidityLayer() internal {
        // Define Base relayers
        address[] memory relayers = new address[](2);
        relayers[0] = Base.ALM_RELAYER;
        relayers[1] = Base.ALM_RELAYER_2;


        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](1);
        mintRecipients[0] = ForeignControllerInit.MintRecipient({
            domain        : CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
        });

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : Base.ALM_PROXY,
                controller : Base.ALM_CONTROLLER,
                rateLimits : Base.ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : Base.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin                    : Base.GROVE_EXECUTOR,
                cctp                     : Base.CCTP_TOKEN_MESSENGER_V2,
                psm                      : Base.PSM3,
                usdc                     : Base.USDC,
                pendleRouter             : Base.PENDLE_ROUTER,
                uniswapV3Router          : Base.UNISWAP_V3_SWAP_ROUTER_02,
                uniswapV3PositionManager : Base.UNISWAP_V3_POSITION_MANAGER
            }),
            mintRecipients,
            new ForeignControllerInit.LayerZeroRecipient[](0),
            new ForeignControllerInit.CentrifugeRecipient[](0)
        );
    }

    function _onboardGroveXSteakhouseUsdcMorphoVault() internal {
        _onboardERC4626Vault({
            vault             : Base.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            depositMax        : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope      : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE,
            shareUnit         : 1e18,
            maxAssetsPerShare : 1.15e6
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

