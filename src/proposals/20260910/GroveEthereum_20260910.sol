// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  September 10, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260910 is GrovePayloadEthereum {

    address internal constant GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT = 0xbeef05061FE51eA482BD1b68041353490b3a5934;

    function _execute() internal override {
        // [Ethereum] Item 1: onboard the Grove x Steakhouse USDG Morpho vault.
        //   Forum : TODO
        _onboardGroveXSteakhouseUsdgMorphoVault();
    }

    function _onboardGroveXSteakhouseUsdgMorphoVault() internal {
        _onboardERC4626Vault({
            vault             : GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT,
            depositMax        : 50_000_000e6,                   // BEFORE: 0
            depositSlope      : 50_000_000e6 / uint256(1 days), // BEFORE: 0
            shareUnit         : 1e18,                           // BEFORE: 0
            maxAssetsPerShare : 2e6                             // BEFORE: 0
        });
    }

}
