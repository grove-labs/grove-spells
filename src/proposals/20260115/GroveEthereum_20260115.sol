// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";
import { LZForwarder }     from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/MainnetControllerInit.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  January 15, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260115 is GrovePayloadEthereum {

    address internal constant NEW_CONTROLLER              = 0xfd9dEA9a8D5B955649579Af482DB7198A392A9F5;
    address internal constant AGORA_AUSD_USDC_MINT_WALLET = 0xfEa17E5f0e9bF5c86D5d553e2A074199F03B44E8;

    // BEFORE :          0 max ;          0/day slope
    // AFTER  : 50,000,000 max ; 50,000,000/day slope
    uint256 internal constant CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    // BEFORE : 50,000,000 max ; 50,000,000/day slope
    // AFTER  :          0 max ;          0/day slope
    uint256 internal constant AGORA_AUSD_USDC_MINT_MAX   = 0;
    uint256 internal constant AGORA_AUSD_USDC_MINT_SLOPE = 0;

    function _execute() internal override {
        // [Mainnet] Upgrade MainnetController to v1.8.0
        //   Forum : https://forum.sky.money/t/january-15th-2025-proposed-changes-to-grove-for-upcoming-spell/27570#p-105288-h-3-mainnet-upgrade-mainnetcontroller-to-v180-14
        _upgradeController();

        // [Base] Onboard Grove Liquidity Layer and CCTP for Base
        //   Forum : https://forum.sky.money/t/january-15th-2025-proposed-changes-to-grove-for-upcoming-spell/27570#p-105288-h-1-base-onboard-grove-liquidity-layer-and-cctp-for-base-2
        _onboardCctpTransfersToBase();

        // [Mainnet] Offboard Agora Mint Deposit Address
        //   Forum : https://forum.sky.money/t/january-15th-2025-proposed-changes-to-grove-for-upcoming-spell/27570#p-105288-h-4-mainnet-offboard-agora-mint-deposit-address-20
        _offboardAgoraAusd();
    }

    function _upgradeController() internal {
        address[] memory relayers = new address[](1);
        relayers[0] = Ethereum.ALM_RELAYER;

        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](3);
        mintRecipients[0] = MainnetControllerInit.MintRecipient({
            domain        : CCTPv2Forwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Avalanche.ALM_PROXY)
        });
        mintRecipients[1] = MainnetControllerInit.MintRecipient({
            domain        : CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY)
        });
        mintRecipients[2] = MainnetControllerInit.MintRecipient({
            domain        : CCTPv2Forwarder.DOMAIN_ID_CIRCLE_PLUME,
            mintRecipient : CastingHelpers.addressToCctpRecipient(Plume.ALM_PROXY)
        });

        MainnetControllerInit.LayerZeroRecipient[] memory layerZeroRecipients = new MainnetControllerInit.LayerZeroRecipient[](3);
        layerZeroRecipients[0] = MainnetControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_AVALANCHE,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Avalanche.ALM_PROXY)
        });
        layerZeroRecipients[1] = MainnetControllerInit.LayerZeroRecipient({
            destinationEndpointId : LZForwarder.ENDPOINT_ID_BASE,
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Base.ALM_PROXY)
        });
        layerZeroRecipients[2] = MainnetControllerInit.LayerZeroRecipient({
            destinationEndpointId : 30318, // Plume endpoint ID
            recipient             : CastingHelpers.addressToLayerZeroRecipient(Plume.ALM_PROXY)
        });

        MainnetControllerInit.CentrifugeRecipient[] memory centrifugeRecipients = new MainnetControllerInit.CentrifugeRecipient[](3);
        centrifugeRecipients[0] = MainnetControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Avalanche.ALM_PROXY)
        });
        centrifugeRecipients[1] = MainnetControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : GroveLiquidityLayerHelpers.BASE_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Base.ALM_PROXY)
        });
        centrifugeRecipients[2] = MainnetControllerInit.CentrifugeRecipient({
            destinationCentrifugeId : GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID,
            recipient               : CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY)
        });


        MainnetControllerInit.upgradeController(
            ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : NEW_CONTROLLER,
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            MainnetControllerInit.ConfigAddressParams({
                freezer       : Ethereum.ALM_FREEZER,
                relayers      : relayers,
                oldController : Ethereum.ALM_CONTROLLER
            }),
            MainnetControllerInit.CheckAddressParams({
                admin                    : Ethereum.GROVE_PROXY,
                proxy                    : Ethereum.ALM_PROXY,
                rateLimits               : Ethereum.ALM_RATE_LIMITS,
                vault                    : Ethereum.ALLOCATOR_VAULT,
                psm                      : Ethereum.PSM,
                daiUsds                  : Ethereum.DAI_USDS,
                cctp                     : Ethereum.CCTP_TOKEN_MESSENGER_V2,
                uniswapV3Router          : Ethereum.UNISWAP_V3_SWAP_ROUTER_02,
                uniswapV3PositionManager : Ethereum.UNISWAP_V3_POSITION_MANAGER
            }),
            mintRecipients,
            layerZeroRecipients,
            centrifugeRecipients
        );

        // Set to make GroveEthereum_20250807 Ethena deposit onboarding backwards compatible
        MainnetController(NEW_CONTROLLER).setMaxExchangeRate(
            Ethereum.SUSDE,
            1e18,
            1.3e18
        );

        // Re-setting the Curve RLUSD/USDC pool slippage set in GroveEthereum_20251030
        MainnetController(NEW_CONTROLLER).setMaxSlippage(
            Ethereum.CURVE_RLUSD_USDC,
            0.9990e18
        );

        // Set to make GroveEthereum_20251030 Aave Core RLUSD onboarding backwards compatible
        MainnetController(NEW_CONTROLLER).setMaxSlippage(
            Ethereum.AAVE_CORE_RLUSD,
            0.9990e18
        );

        // Set to make GroveEthereum_20251030 Aave Core USDC onboarding backwards compatible
        MainnetController(NEW_CONTROLLER).setMaxSlippage(
            Ethereum.AAVE_CORE_USDC,
            0.9990e18
        );

        // Set to make GroveEthereum_20251030 Aave Horizon RLUSD onboarding backwards compatible
        MainnetController(NEW_CONTROLLER).setMaxSlippage(
            Ethereum.AAVE_HORIZON_RLUSD,
            0.9990e18
        );

        // Set to make GroveEthereum_20251030 Aave Horizon USDC onboarding backwards compatible
        MainnetController(NEW_CONTROLLER).setMaxSlippage(
            Ethereum.AAVE_HORIZON_USDC,
            0.9990e18
        );

        // Set to make GroveEthereum_20251211 Morpho vault onboarding backwards compatible
        MainnetController(NEW_CONTROLLER).setMaxExchangeRate(
            Ethereum.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            1e18,
            1.15e6
        );
    }

    function _onboardCctpTransfersToBase() internal {
        // General key rate limit for all CCTP transfers was set in the GroveEthereum_20250807 proposal

        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(domainKey, CCTP_RATE_LIMIT_MAX, CCTP_RATE_LIMIT_SLOPE);
    }

    function _offboardAgoraAusd() internal {
        bytes32 mintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            AGORA_AUSD_USDC_MINT_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            mintKey,
            AGORA_AUSD_USDC_MINT_MAX,
            AGORA_AUSD_USDC_MINT_SLOPE
        );
    }

}
