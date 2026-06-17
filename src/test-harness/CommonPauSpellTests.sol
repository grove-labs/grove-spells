// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { CommonPauTestBase } from "./CommonPauTestBase.sol";

import { CommonSpellTests } from "./CommonSpellTests.sol";

/// @dev Spell tests specific to the PAU controller system
/// (diamond-pau Controller + AccessControls + AdministeredAgent allocators).
/// The PAU system launches mainnet-only with the Basin facet, so there are no
/// auto-running system-wide tests yet. Once the system gains cross-chain
/// recipients or other spell-wide invariants, they belong here (mirroring
/// CommonALMSpellTests for the legacy ALM system).
abstract contract CommonPauSpellTests is CommonSpellTests, CommonPauTestBase {

    bytes32 internal constant GROVE_PAU_ALLOCATOR_ILK = "ALLOCATOR-GROVE-A";

}
