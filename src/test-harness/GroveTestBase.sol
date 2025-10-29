// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { CommonTestBase }           from "./test-bases/CommonTestBase.sol";
import { GroveLiquidityLayerTests } from "./test-bases/GroveLiquidityLayerTests.sol";

import { CommonSpellTests } from "./CommonSpellTests.sol";

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specifictest contracts
abstract contract GroveTestBase is
    GroveLiquidityLayerTests,
    CommonSpellTests,
    CommonTestBase
{}
