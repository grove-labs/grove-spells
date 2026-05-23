// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { AaveTestingBase }           from "./test-bases/AaveTestingBase.sol";
import { CentrifugeTestingBase }     from "./test-bases/CentrifugeTestingBase.sol";
import { CurveTestingBase }          from "./test-bases/CurveTestingBase.sol";
import { DeploymentsTestingBase }    from "./test-bases/DeploymentsTestingBase.sol";
import { ERC20TestingBase }          from "./test-bases/ERC20TestingBase.sol";
import { ERC4626TestingBase }        from "./test-bases/ERC4626TestingBase.sol";
import { InitializationTestingBase } from "./test-bases/InitializationTestingBase.sol";
import { UniswapV3TestingBase }      from "./test-bases/UniswapV3TestingBase.sol";

import { CommonSpellTests } from "./CommonSpellTests.sol";

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specific test contracts
abstract contract GroveTestBase is
    CommonSpellTests,
    AaveTestingBase,
    CentrifugeTestingBase,
    CurveTestingBase,
    DeploymentsTestingBase,
    ERC20TestingBase,
    ERC4626TestingBase,
    InitializationTestingBase,
    UniswapV3TestingBase
{}
