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
        // fork block, so running here as well would only repeat those assertions at a
        // second block. Skipping before setupDomains also avoids forking five chains.
        if (_activeSpellExists()) {
            vm.skip(true);
            return;
        }

        setupDomains(previousUtcMidnight());
    }

    function _activeSpellExists() private returns (bool) {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-lc";
        cmd[2] = "ls src/proposals/*/GroveEthereum_*.t.sol >/dev/null 2>&1 && printf yes || printf no";

        return keccak256(vm.ffi(cmd)) == keccak256(bytes("yes"));
    }

}
