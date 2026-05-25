// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IUsdsPsmWrapperLike {
    function sellGem(address usr, uint256 gemAmt) external returns (uint256 usdsOut);
}

/**
 * @title  June 4, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260604 is GrovePayloadEthereum {

    address internal constant WRAPPER_USDS_LITE_PSM_USDC_A = 0xA188EEC8F81263234dA3622A406892F3D630f98c;

    function _execute() internal override {
        // [Ethereum] Grove Treasury — Monthly Grant for Grove Foundation (Months 2 + 3 combined)
        //   Forum : https://forum.skyeco.com/t/june-4-2026-proposed-changes-to-grove-for-upcoming-spell/27924
        _transferMonthlyGrantToGroveFoundation();

        // [Ethereum] Transfer GROVE Tokens to Grove Foundation
        //   Forum : https://forum.skyeco.com/t/june-4-2026-proposed-changes-to-grove-for-upcoming-spell/27924
        _transferGroveTokensToGroveFoundation();

        // [Ethereum] Swap USDC to USDS in Grove SubProxy
        //   Forum : https://forum.skyeco.com/t/june-4-2026-proposed-changes-to-grove-for-upcoming-spell/27924
        _swapUsdcToUsdsViaPsm();
    }

    function _transferMonthlyGrantToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(Ethereum.GROVE_FOUNDATION, 1_600_000e18));
    }

    function _transferGroveTokensToGroveFoundation() internal {
        require(IERC20Like(Ethereum.GROVE_TOKEN).transfer(Ethereum.GROVE_FOUNDATION, 500_000_000e18));
    }

    function _swapUsdcToUsdsViaPsm() internal {
        require(IERC20Like(Ethereum.USDC).approve(WRAPPER_USDS_LITE_PSM_USDC_A, 753_649e6));
        IUsdsPsmWrapperLike(WRAPPER_USDS_LITE_PSM_USDC_A).sellGem(address(this), 753_649e6);
    }

}
