// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { GroveLiquidityLayerTests } from "./GroveLiquidityLayerTests.sol";
import { CommonSpellAssertions }    from "./CommonSpellAssertions.sol";
import { CommonTestBase }           from "./CommonTestBase.sol";

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specifictest contracts
abstract contract GroveTestBase is GroveLiquidityLayerTests, CommonSpellAssertions, CommonTestBase {
}
