// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

/// @dev Runs the harness' shared assertions against recent chain state while no spell is
/// in flight. Between cycles `src/proposals/` is empty, so without this contract
/// `forge test` matches nothing on the default branch and a green run only means the
/// project compiled. Configuring no payload makes the execution step inert, leaving each
/// inherited test asserting live chain state; those that only hold post-execution skip
/// themselves.
contract GroveStateTests is GroveTestBase {

    function setUp() public {
        // An active spell already runs every shared test post-execution at its own pinned
        // fork block, so running here as well would only repeat those assertions at a second
        // block. vm.skip reverts out of setUp, so this also avoids forking five chains.
        vm.skip(_spellSuiteInFlight());

        setupDomains(previousUtcMidnight());
    }

}
