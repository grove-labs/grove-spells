// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  February 12, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260212 is GrovePayloadEthereum {

    address internal constant GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT = 0xBEEfF0d672ab7F5018dFB614c93981045D4aA98a;

    function _execute() internal override {
        // [Mainnet] Onboard Grove x Steakhouse AUSD Morpho Vault V2
        //   Forum : https://forum.sky.money/t/february-12-2026-proposed-changes-to-grove-for-upcoming-spell/27662#p-105571-h-1-mainnet-onboard-grove-x-steakhouse-ausd-morpho-vault-v2-2
        _onboardGroveXSteakhouseAusdMorphoVault();
    }

    function _onboardGroveXSteakhouseAusdMorphoVault() internal {
        _onboardERC4626Vault({
            vault             : GROVE_X_STEAKHOUSE_AUSD_MORPHO_VAULT,
            depositMax        : 20_000_000e6,                   // BEFORE: 0
            depositSlope      : 20_000_000e6 / uint256(1 days), // BEFORE: 0
            shareUnit         : 1e18,                           // BEFORE: 0
            maxAssetsPerShare : 2e6                             // BEFORE: 0
        });
    }

}
