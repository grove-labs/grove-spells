// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

abstract contract CommonSpellAssertions is Test {

    /**
     * @notice Asserts the USDS and USDC balances of the ALM proxy
     * @param usds The expected USDS balance
     * @param usdc The expected USDC balance
     */
    function _assertMainnetAlmProxyBalances(
        uint256 usds,
        uint256 usdc
    ) internal {
        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.ALM_PROXY), usds, "incorrect-alm-proxy-usds-balance");
        assertEq(IERC20(Ethereum.USDC).balanceOf(Ethereum.ALM_PROXY), usdc, "incorrect-alm-proxy-usdc-balance");
    }

}
