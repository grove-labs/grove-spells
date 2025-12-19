// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { GroveLiquidityLayerContext, CommonTestBase } from "../CommonTestBase.sol";

abstract contract InitializationTestingBase is CommonTestBase {

    struct ControllerConfigParams {
        address   freezer;
        address[] relayers;
    }

    function _testControllerInitialization(address newController, ControllerConfigParams memory configParams) internal {
        _testControllerUpgrade(address(0), newController, configParams);
    }

    function _testControllerUpgrade(address oldController, address newController, ControllerConfigParams memory configParams) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        // Note the functions used are interchangeable with mainnet and foreign controllers
        MainnetController controller = MainnetController(newController);

        bytes32 CONTROLLER = ctx.proxy.CONTROLLER();
        bytes32 RELAYER    = controller.RELAYER();
        bytes32 FREEZER    = controller.FREEZER();

        // Old controller address is assigned as a CONTROLLER role in the proxy and new controller is not
        if (oldController != address(0)) {
            assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), true, "InitTest/incorrect-old-controller-proxy");
        }
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), false, "InitTest/incorrect-new-controller-proxy");

        // Old controller address is assigned as a CONTROLLER role in the rate limits and new controller is not
        if (oldController != address(0)) {
            assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), true, "InitTest/incorrect-old-controller-rate-limits");
        }
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), false, "InitTest/incorrect-new-controller-rate-limits");

        // Freezer and relayers roles are not granted in the new controller before the initialization
        assertEq(controller.hasRole(FREEZER, configParams.freezer), false, "InitTest/freezer-incorrectly-pre-granted");
        for (uint256 i = 0; i < configParams.relayers.length; i++) {
            assertEq(controller.hasRole(RELAYER, configParams.relayers[i]), false, "InitTest/relayer-incorrectly-pre-granted");
        }

        executeAllPayloadsAndBridges();

        // Old controller address is revoked as a CONTROLLER role in the proxy and new controller is granted
        assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), false, "InitTest/old-controller-not-revoked-proxy");
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), true, "InitTest/new-controller-not-granted-proxy");

        // Old controller address is revoked as a CONTROLLER role in the rate limits and new controller is granted
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), false, "InitTest/old-controller-not-revoked-rate-limits");
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), true, "InitTest/new-controller-not-granted-rate-limits");

        // Freezer and relayers roles are granted in the new controller after the initialization
        assertEq(controller.hasRole(FREEZER, configParams.freezer), true, "InitTest/freezer-not-granted");
        for (uint256 i = 0; i < configParams.relayers.length; i++) {
            assertEq(controller.hasRole(RELAYER, configParams.relayers[i]), true, "InitTest/relayer-not-granted");
        }
    }

}
