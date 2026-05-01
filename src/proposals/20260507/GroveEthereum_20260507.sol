// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}

/**
 * @title  May 7, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260507 is GrovePayloadEthereum {

    address internal constant GROVE_X_STEAKHOUSE_RLUSD_V2 = 0xBeEff4fD39F8e48b6a6e475445D650cb11e9599F;

    address internal constant GROVE_FOUNDATION = 0xE3EC4CC359E68c9dCE15Bf667b1aD37Df54a5a42;

    uint256 internal constant GROVE_FOUNDATION_GRANT_AMOUNT = 800_000e18;

    function _execute() internal override {
        // [Ethereum] Onboard Grove x Steakhouse RLUSD Morpho Vault V2
        //   Forum : https://forum.skyeco.com/t/may-7-2026-proposed-changes-to-grove-for-upcoming-spell/27858#p-106239-h-2-ethereum-onboard-grove-x-steakhouse-rlusd-morpho-vault-v2-8
        _onboardGroveXSteakhouseRlusdMorphoVaultV2();

        // [Ethereum] Grove Treasury — Monthly Grant for Grove Foundation
        //   Forum : https://forum.skyeco.com/t/may-7-2026-proposed-changes-to-grove-for-upcoming-spell/27858#p-106239-h-3-ethereum-grove-treasury-monthly-grant-for-grove-foundation-15
        _transferMonthlyGrantToGroveFoundation();
    }

    function _onboardGroveXSteakhouseRlusdMorphoVaultV2() internal {
        _onboardERC4626Vault({
            vault             : GROVE_X_STEAKHOUSE_RLUSD_V2,
            depositMax        : 100_000_000e18,                   // BEFORE: 0
            depositSlope      : 100_000_000e18 / uint256(1 days), // BEFORE: 0
            shareUnit         : 1e18,                             // BEFORE: 0
            maxAssetsPerShare : 3e18                              // BEFORE: 0
        });
    }

    function _transferMonthlyGrantToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(GROVE_FOUNDATION, GROVE_FOUNDATION_GRANT_AMOUNT));
    }

}
