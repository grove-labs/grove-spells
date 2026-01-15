// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { UniswapV3Helpers } from "src/libraries/helpers/UniswapV3Helpers.sol";

import { CommonTestBase } from "../CommonTestBase.sol";

abstract contract UniswapV3TestingBase is CommonTestBase {

    function _testUniswapV3Onboarding(
        address pool,
        uint256 expectedDepositAmountToken0,
        uint256 expectedSwapAmountToken0,
        uint256 expectedDepositAmountToken1,
        uint256 expectedSwapAmountToken1,
        UniswapV3Helpers.UniswapV3PoolParams  memory poolParams,
        UniswapV3Helpers.UniswapV3TokenParams memory token0Params,
        UniswapV3Helpers.UniswapV3TokenParams memory token1Params
    ) internal {
        // TODO Test pre-execution state

        executeAllPayloadsAndBridges();

        // TODO Test post-execution state

        // TODO Test flow of swapping, depositing, and withdrawing
    }

}
