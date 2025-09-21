// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }    from "lib/grove-address-registry/src/Plume.sol";

import { RateLimitHelpers } from "grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/GroveLiquidityLayerHelpers.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250918_Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    uint256 internal constant MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 20_000_000e6;
    uint256 internal constant MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_MAX   = 20_000_000e6;
    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE = 20_000_000e6 / uint256(1 days);
    uint256 internal constant PLUME_JTRSY_REDEEM_RATE_LIMIT_MAX    = 20_000_000e6;
    uint256 internal constant PLUME_JTRSY_REDEEM_RATE_LIMIT_SLOPE  = 20_000_000e6 / uint256(1 days);

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID = 1;
    uint16 internal constant PLUME_DESTINATION_CENTRIFUGE_ID    = 4;

    constructor() {
        id = "20250918";
    }

    function setUp() public {
        setupDomains("2025-09-20T12:00:00Z");

        deployPayloads();
    }

    function test_ETHEREUM_onboardCentrifugeJtrsyCrosschainTransfer() public onChain(ChainIdUtils.Ethereum()) {
        _testCentrifugeCrosschainTransferOnboarding({
            centrifugeVault         : Ethereum.CENTRIFUGE_JTRSY,
            destinationAddress      : Plume.ALM_PROXY,
            destinationCentrifugeId : PLUME_DESTINATION_CENTRIFUGE_ID,
            maxAmount               : MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            slope                   : MAINNET_JTRSY_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        });
    }

    function test_PLUME_governanceDeployment() public onChain(ChainIdUtils.Plume()) {
        _verifyForeignDomainExecutorDeployment({
            _executor : Plume.GROVE_EXECUTOR,
            _receiver : Plume.GROVE_RECEIVER,
            _deployer : DEPLOYER
        });
        _verifyArbitrumReceiverDeployment({
            _executor : Plume.GROVE_EXECUTOR,
            _receiver : Plume.GROVE_RECEIVER
        });
    }

    function test_PLUME_almSystemDeployment() public onChain(ChainIdUtils.Plume()) {
        _verifyForeignAlmSystemDeployment(
            AlmSystemContracts({
                admin      : Plume.GROVE_EXECUTOR,
                proxy      : Plume.ALM_PROXY,
                rateLimits : Plume.ALM_RATE_LIMITS,
                controller : Plume.ALM_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
                freezer  : Plume.ALM_FREEZER,
                relayer  : Plume.ALM_RELAYER
            }),
            ForeignAlmSystemDependencies({
                psm  : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                usdc : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                cctp : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER
            })
        );
    }

    function test_PLUME_onboardCentrifugeAcrdx() public onChain(ChainIdUtils.Plume()) {
        _testCentrifugeV3Onboarding({
            centrifugeVault       : Plume.CENTRIFUGE_ACRDX,
            depositMax            : PLUME_ACRDX_DEPOSIT_RATE_LIMIT_MAX,
            depositSlope          : PLUME_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE
        });
    }

    function test_PLUME_onboardCentrifugeJtrsyRedemption() public onChain(ChainIdUtils.Plume()) {
        _testCentrifugeV3RedemptionsOnlyOnboarding({
            centrifugeVault  : Plume.CENTRIFUGE_JTRSY,
            redeemMax        : PLUME_JTRSY_REDEEM_RATE_LIMIT_MAX,
            redeemSlope      : PLUME_JTRSY_REDEEM_RATE_LIMIT_SLOPE
        });
    }

}
