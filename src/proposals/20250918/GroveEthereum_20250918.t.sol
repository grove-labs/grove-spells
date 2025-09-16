// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Plume }    from "lib/grove-address-registry/src/Plume.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250918_Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant FAKE_ADDRESS_PLACEHOLDER = 0x00000000000000000000000000000000DeaDBeef;

    address internal constant MAINNET_CENTRIFUGE_ACRDX_VAULT = 0x0000000000000000000000000000000000000000; // TODO: Add actual address
    address internal constant PLUME_CENTRIFUGE_ACRDX_VAULT   = 0x0000000000000000000000000000000000000000; // TODO: Add actual address

    uint256 internal constant PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                   // TODO: Add actual value
    uint256 internal constant PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 100_000_000e6 / uint256(1 days); // TODO: Add actual value
    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_MAX               = 20_000_000e6;                   // TODO: Add actual value
    uint256 internal constant PLUME_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE             = 20_000_000e6 / uint256(1 days); // TODO: Add actual value

    uint256 internal constant MAINNET_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX   = 100_000_000e6;                   // TODO: Add actual value
    uint256 internal constant MAINNET_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE = 100_000_000e6 / uint256(1 days); // TODO: Add actual value
    uint256 internal constant MAINNET_ACRDX_DEPOSIT_RATE_LIMIT_MAX               = 20_000_000e6;                   // TODO: Add actual value
    uint256 internal constant MAINNET_ACRDX_DEPOSIT_RATE_LIMIT_SLOPE             = 20_000_000e6 / uint256(1 days); // TODO: Add actual value

    uint16 internal constant ETHEREUM_DESTINATION_CENTRIFUGE_ID = 1;
    uint16 internal constant PLUME_DESTINATION_CENTRIFUGE_ID    = 9999; // TODO: Add actual value

    constructor() {
        id = "20250918";
    }

    function setUp() public {
        setupDomains("2025-08-25T15:30:00Z");
    }

    function test_ETHEREUM_onboardCctpTransfersToPlume() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Unskip and implement after the CCTP transfers to Plume are onboarded
        vm.skip(true);
    }

    function test_ETHEREUM_onboardCentrifugeAcrdx() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Unskip and implement after the Centrifuge Acrdx vault is deployed
        vm.skip(true);
    }

    function test_ETHEREUM_onboardCentrifugeAcrdxCrosschainTransfer() public onChain(ChainIdUtils.Ethereum()) {
        // TODO: Unskip and implement after the Centrifuge Acrdx vault is deployed
        vm.skip(true);
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
                psm  : FAKE_ADDRESS_PLACEHOLDER,
                usdc : FAKE_ADDRESS_PLACEHOLDER,
                cctp : FAKE_ADDRESS_PLACEHOLDER
            })
        );
    }

    function test_PLUME_onboardCctpTransfersToEthereum() public onChain(ChainIdUtils.Plume()) {
        // TODO: Unskip and implement after the CCTP transfers to Ethereum are onboarded
        vm.skip(true);
    }

    function test_PLUME_onboardCentrifugeAcrdx() public onChain(ChainIdUtils.Plume()) {
        // TODO: Unskip  and implement after the Centrifuge Acrdx vault is deployed
        vm.skip(true);
    }

    function test_PLUME_onboardCentrifugeAcrdxCrosschainTransfer() public onChain(ChainIdUtils.Plume()) {
        // TODO: Unskip after the Centrifuge Acrdx vault is deployed
        vm.skip(true);

        _testCentrifugeCrosschainTransferOnboarding({
            centrifugeVault         : PLUME_CENTRIFUGE_ACRDX_VAULT,
            destinationAddress      : Ethereum.ALM_PROXY,
            destinationCentrifugeId : ETHEREUM_DESTINATION_CENTRIFUGE_ID,
            expectedTransferAmount  : 10_000_000e6,
            maxAmount               : PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_MAX,
            slope                   : PLUME_ACRDX_CROSSCHAIN_TRANSFER_RATE_LIMIT_SLOPE
        });
    }

}
