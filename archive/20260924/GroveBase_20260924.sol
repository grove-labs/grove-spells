// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { GrovePayloadBase } from "src/libraries/payloads/GrovePayloadBase.sol";

/**
 * @title  September 24, 2026 Grove Base Proposal
 * @author Grove Labs
 */
contract GroveBase_20260924 is GrovePayloadBase {

    address internal constant GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT = 0xbeef0786756810478b88982DE00F3CD7fdB8e7c7;

    function execute() external {
        // [Base] Item 2: onboard the Grove x Steakhouse USDC Morpho vault.
        //   Forum : https://forum.skyeco.com/t/september-24-2026-proposed-changes-to-grove-for-upcoming-spell/28229
        _onboardGroveXSteakhouseUsdcV2MorphoVault();
    }

    function _onboardGroveXSteakhouseUsdcV2MorphoVault() internal {
        _onboardERC4626Vault({
            vault             : GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT,
            depositMax        : 20_000_000e6,                   // BEFORE: 0
            depositSlope      : 20_000_000e6 / uint256(1 days), // BEFORE: 0
            shareUnit         : 1e18,                           // BEFORE: 0
            maxAssetsPerShare : 1.15e6                          // BEFORE: 0
        //  withdrawMax       : unlimited                          BEFORE: 0
        //  withdrawSlope     : 0                                  BEFORE: 0
        });
    }

}
