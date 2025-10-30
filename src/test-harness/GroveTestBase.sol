// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { AaveTestingBase }        from "./test-bases/AaveTestingBase.sol";
import { CentrifugeTestingBase}   from "./test-bases/CentrifugeTestingBase.sol";
import { CurveTestingBase }       from "./test-bases/CurveTestingBase.sol";
import { DeploymentsTestingBase } from "./test-bases/DeploymentsTestingBase.sol";
import { ERC4626TestingBase }     from "./test-bases/ERC4626TestingBase.sol";

import { CommonSpellTests } from "./CommonSpellTests.sol";

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specific test contracts
abstract contract GroveTestBase is
    CommonSpellTests,
    AaveTestingBase,
    CentrifugeTestingBase,
    CurveTestingBase,
    DeploymentsTestingBase,
    ERC4626TestingBase
{}
