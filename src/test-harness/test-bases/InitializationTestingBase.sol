// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Avalanche } from "grove-address-registry/Avalanche.sol";
import { Ethereum }  from "grove-address-registry/Ethereum.sol";
import { Plume }     from "grove-address-registry/Plume.sol";
import { Base }      from "grove-address-registry/Base.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { ChainId, ChainIdUtils }      from "src/libraries/helpers/ChainId.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveLiquidityLayerContext, CommonTestBase } from "../CommonTestBase.sol";

abstract contract InitializationTestingBase is CommonTestBase {

    function _testControllerInitialization(address newController) internal {
        _testControllerUpgrade(address(0), newController);
    }

    function _testControllerUpgrade(address oldController, address newController) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        // Note the functions used are interchangeable with mainnet and foreign controllers
        MainnetController controller = MainnetController(newController);

        bytes32 CONTROLLER = ctx.proxy.CONTROLLER();
        bytes32 RELAYER    = controller.RELAYER();
        bytes32 FREEZER    = controller.FREEZER();

        if (oldController != address(0)) {
            assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), true, "InitTest/incorrect-old-controller");
        }
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), false, "InitTest/incorrect-new-controller");

        if (oldController != address(0)) {
            assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), true, "InitTest/incorrect-old-controller");
        }
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), false, "InitTest/incorrect-new-controller");

        assertEq(controller.hasRole(RELAYER, ctx.relayer), false, "InitTest/relayer-incorrectly-preset");
        assertEq(controller.hasRole(FREEZER, ctx.freezer), false, "InitTest/freezer-incorrectly-preset");

        executeAllPayloadsAndBridges();

        assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), false, "InitTest/old-controller-not-revoked");
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), true, "InitTest/new-controller-not-granted");

        assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), false, "InitTest/old-controller-not-revoked");
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), true, "InitTest/new-controller-not-granted");

        assertEq(controller.hasRole(RELAYER, ctx.relayer), true, "InitTest/relayer-not-granted");
        assertEq(controller.hasRole(FREEZER, ctx.freezer), true, "InitTest/freezer-not-granted");
    }

}
