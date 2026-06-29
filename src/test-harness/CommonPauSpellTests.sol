// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { CommonPauTestBase } from "./CommonPauTestBase.sol";

import { CommonSpellTests } from "./CommonSpellTests.sol";

interface IAllocatorVaultLike {
    function jug() external view returns (address);
}

interface IJugLike {
    function ilks(bytes32 ilk) external view returns (uint256 duty, uint256 rho);
}

/// @dev Spell tests specific to the PAU controller system
/// (diamond-pau Controller + AccessControls + AdministeredAgent allocators).
/// Spell-wide PAU invariants belong here (mirroring CommonALMSpellTests for the
/// legacy ALM system).
abstract contract CommonPauSpellTests is CommonSpellTests, CommonPauTestBase {

    bytes32 internal constant GROVE_PAU_ALLOCATOR_ILK = "ALLOCATOR-GROVE-A";

    // The Sky ALLOCATOR-GROVE-A vault the PAU system mints USDS through.
    address internal constant ALLOCATOR_GROVE_A_VAULT = Ethereum.ALLOCATOR_GROVE_A_VAULT;

    /// @dev The PAU mint/burn path draws debt against the ALLOCATOR-GROVE-A ilk and assumes a
    ///      0% stability fee, so assert the ilk duty is RAY (1e27) on the live jug.
    function test_ETHEREUM_PauAllocatorIlkHasZeroFee() public onChain(ChainIdUtils.Ethereum()) {
        address jug = IAllocatorVaultLike(ALLOCATOR_GROVE_A_VAULT).jug();
        ( uint256 duty, ) = IJugLike(jug).ilks(GROVE_PAU_ALLOCATOR_ILK);

        assertEq(duty, 1e27, "CommonPauTest/ilk-duty-not-zero-fee");
    }

}
