// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }    from "lib/grove-address-registry/src/Plume.sol";

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { CastingHelpers } from "src/libraries/CastingHelpers.sol";

import { GrovePayloadPlume } from "src/libraries/GrovePayloadPlume.sol";

contract GrovePlume_20250918 is GrovePayloadPlume {

    address internal constant FAKE_ADDRESS_PLACEHOLDER    = 0x00000000000000000000000000000000DeaDBeef;
    address internal constant PLUME_CENTRIFUGE_ACRDX_VAULT = 0x0000000000000000000000000000000000000000; // TODO: Add actual address

    uint256 internal constant PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                   // TODO: Add actual value
    uint256 internal constant PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 100_000_000e6 / uint256(1 days); // TODO: Add actual value
    uint256 internal constant CCTP_RATE_LIMIT_MAX                              = 50_000_000e6;                   // TODO: Add actual value
    uint256 internal constant CCTP_RATE_LIMIT_SLOPE                            = 50_000_000e6 / uint256(1 days); // TODO: Add actual value
    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_MAX               = 20_000_000e6;                   // TODO: Add actual value
    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE             = 20_000_000e6 / uint256(1 days); // TODO: Add actual value

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID = 1;

    function execute() external {
        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _initializeLiquidityLayer();

        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _onboardCctpTransfersToEthereum();

        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _onboardCentrifugeAcrdx();

        // TODO: Add item title
        //   Forum : TODO: Add link
        //   Poll  : TODO: Add link
        _onboardCentrifugeAcrdxCrosschainTransfer();
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
                psm        : FAKE_ADDRESS_PLACEHOLDER,
                cctp       : Plume.CCTP_TOKEN_MESSENGER,
                usdc       : Plume.USDC
            }),
            cctpRecipients,
            new ForeignControllerInit.LayerZeroRecipient[](0),
            centrifugeRecipients
        );
    }

    function _onboardCctpTransfersToEthereum() internal {
        bytes32 generalCctpKey = ForeignController(Plume.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 ethereumCctpKey = RateLimitHelpers.makeDomainKey(
            ForeignController(Plume.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        IRateLimits(Plume.ALM_RATE_LIMITS).setUnlimitedRateLimitData(generalCctpKey);

        IRateLimits(Plume.ALM_RATE_LIMITS).setRateLimitData({
            key       : ethereumCctpKey,
            maxAmount : CCTP_RATE_LIMIT_MAX,
            slope     : CCTP_RATE_LIMIT_SLOPE
        });

        // Mint recipients are set during the ForeignController initialization
    }

    function _onboardCentrifugeAcrdx() internal {
        _onboardERC7540Vault(
            PLUME_CENTRIFUGE_ACRDX_VAULT,
            PLUME_ACRDX_DEPOSIT_RATE_LIMIT_MAX,
            PLUME_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE
        );
    }

    function _onboardCentrifugeAcrdxCrosschainTransfer() internal {
        _setCentrifugeCrosschainTransferRateLimit(
            PLUME_CENTRIFUGE_ACRDX_VAULT,
            ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        );
    }
}
