// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Base }     from "lib/grove-address-registry/src/Base.sol";
import { Plasma }   from "lib/grove-address-registry/src/Plasma.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20251030_Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    constructor() {
        id = "20251113";
    }

    function setUp() public {
        setupDomains("2025-10-30T12:00:00Z");

        deployPayloads();
    }

    function test_BASE_governanceDeployment() public onChain(ChainIdUtils.Base()) {
        _verifyForeignDomainExecutorDeployment({
            _executor : Base.GROVE_EXECUTOR,
            _receiver : Base.GROVE_RECEIVER,
            _deployer : DEPLOYER
        });
        _verifyArbitrumReceiverDeployment({
            _executor : Base.GROVE_EXECUTOR,
            _receiver : Base.GROVE_RECEIVER
        });
    }

    function test_BASE_almSystemDeployment() public onChain(ChainIdUtils.Base()) {
        _verifyForeignAlmSystemDeployment(
            AlmSystemContracts({
                admin      : Base.GROVE_EXECUTOR,
                proxy      : Base.ALM_PROXY,
                rateLimits : Base.ALM_RATE_LIMITS,
                controller : Base.ALM_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
                freezer  : Base.ALM_FREEZER,
                relayer  : Base.ALM_RELAYER
            }),
            ForeignAlmSystemDependencies({
                cctp : 0x1682Ae6375C4E4A97e4B583BC394c861A46D8962, // TODO: Use address registry - CCTP Messenger
                psm  : 0x1601843c5E9bC251A3272907010AFa41Fa18347E, // TODO: Use address registry - PSM3
                usdc : Base.USDC
            })
        );
    }

    function test_PLASMA_governanceDeployment() public onChain(ChainIdUtils.Plasma()) {
        _verifyForeignDomainExecutorDeployment({
            _executor : Plasma.GROVE_EXECUTOR,
            _receiver : Plasma.GROVE_RECEIVER,
            _deployer : DEPLOYER
        });
        // TODO: Implement
        // _verifyLayerZeroReceiverDeployment({
        //     _executor : Plasma.GROVE_EXECUTOR,
        //     _receiver : Plasma.GROVE_RECEIVER
        // });
    }

    function test_PLASMA_almSystemDeployment() public onChain(ChainIdUtils.Plasma()) {
        _verifyForeignAlmSystemDeployment(
            AlmSystemContracts({
                admin      : Plasma.GROVE_EXECUTOR,
                proxy      : Plasma.ALM_PROXY,
                rateLimits : Plasma.ALM_RATE_LIMITS,
                controller : Plasma.ALM_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
                freezer  : Plasma.ALM_FREEZER,
                relayer  : Plasma.ALM_RELAYER
            }),
            ForeignAlmSystemDependencies({
                psm  : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                usdc : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER,
                cctp : GroveLiquidityLayerHelpers.BLANK_ADDRESS_PLACEHOLDER
            })
        );
    }

}
