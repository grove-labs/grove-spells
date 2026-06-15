// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { CommonPAUTestBase } from "./CommonPAUTestBase.sol";

import { CommonSpellTests } from "./CommonSpellTests.sol";

/// @dev Spell tests specific to the DPAU controller system
/// (diamond-pau Controller + AccessControls + AdministeredAgent allocators).
/// The DPAU system launches mainnet-only with the Basin facet, so there are no
/// auto-running system-wide tests yet. Once the system gains cross-chain
/// recipients or other spell-wide invariants, they belong here (mirroring
/// CommonALMSpellTests for the legacy ALM system).
abstract contract CommonPAUSpellTests is CommonSpellTests, CommonPAUTestBase {

    bytes32 internal constant GROVE_PAU_ALLOCATOR_ILK = "ALLOCATOR-GROVE-A";

}
