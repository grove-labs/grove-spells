// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { GrovePayloadBase } from "src/libraries/payloads/GrovePayloadBase.sol";

/**
 * @title  February 26, 2026 Grove Base Proposal
 * @author Grove Labs
 */
contract GroveBase_20260226 is GrovePayloadBase {

    address internal constant STEAKHOUSE_MORPHO_USDC_VAULT = 0xbeef0e0834849aCC03f0089F01f4F1Eeb06873C9;

    function execute() external {
        // [Base] Onboard Steakhouse Prime Instant USDC Morpho Vault V2
        //   Forum : https://forum.sky.money/t/february-26-2026-proposed-changes-to-grove-for-upcoming-spell/27712#p-105710-h-1-base-onboard-steakhouse-prime-instant-usdc-morpho-vault-v2-2
        _onboardSteakhouseMorphoUsdcVault();
    }

    function _onboardSteakhouseMorphoUsdcVault() internal {
        _onboardERC4626Vault({
            vault             : STEAKHOUSE_MORPHO_USDC_VAULT,
            depositMax        : 20_000_000e6,                   // BEFORE: 0
            depositSlope      : 20_000_000e6 / uint256(1 days), // BEFORE: 0
            shareUnit         : 1e18,                           // BEFORE: 0
            maxAssetsPerShare : 2e6                             // BEFORE: 0
        });
    }

}
