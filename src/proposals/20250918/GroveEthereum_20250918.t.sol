// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { Plume } from "grove-address-registry/Plume.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250918_Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant FAKE_ADDRESS_PLACEHOLDER = 0x00000000000000000000000000000000DeaDBeef;

    constructor() {
        id = "20250918";
    }

    function setUp() public {
        setupDomains("2025-08-22T16:00:00Z");
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
}
