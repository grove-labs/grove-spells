// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  March 26, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260326 is GrovePayloadEthereum {

    address internal constant CENTRIFUGE_ACRDX      = 0x74A739EA1Dc67c5a0179ebad665D1D3c4b80B712;
    address internal constant SENTORA_PYUSD_MAIN_V2 = 0xb576765fB15505433aF24FEe2c0325895C559FB2;
    address internal constant SENTORA_RLUSD_MAIN_V2 = 0x6dC58a0FdfC8D694e571DC59B9A52EEEa780E6bf;

    function _execute() internal override {
        // [Ethereum] Onboard Centrifuge ACRDX
        //   Forum : TODO
        _onboardCentrifugeAcrdx();

        // [Ethereum] Onboard Sentora PYUSD Morpho Vault V2
        //   Forum : TODO
        _onboardSentoraPyusdMorphoVault();

        // [Ethereum] Onboard Sentora RLUSD Morpho Vault V2
        //   Forum : TODO
        _onboardSentoraRlusdMorphoVault();
    }

    function _onboardCentrifugeAcrdx() internal {
        _onboardERC7540Vault({
            vault        : CENTRIFUGE_ACRDX,
            depositMax   : 20_000_000e6,                  // BEFORE: 0
            depositSlope : 20_000_000e6 / uint256(1 days) // BEFORE: 0
        });
    }

    function _onboardSentoraPyusdMorphoVault() internal {
        _onboardERC4626Vault({
            vault             : SENTORA_PYUSD_MAIN_V2,
            depositMax        : 50_000_000e6,                   // BEFORE: 0
            depositSlope      : 50_000_000e6 / uint256(1 days), // BEFORE: 0
            shareUnit         : 1e18,                           // BEFORE: 0
            maxAssetsPerShare : 3e6                             // BEFORE: 0
        });
    }

    function _onboardSentoraRlusdMorphoVault() internal {
        _onboardERC4626Vault({
            vault             : SENTORA_RLUSD_MAIN_V2,
            depositMax        : 50_000_000e18,                   // BEFORE: 0
            depositSlope      : 50_000_000e18 / uint256(1 days), // BEFORE: 0
            shareUnit         : 1e18,                            // BEFORE: 0
            maxAssetsPerShare : 3e18                             // BEFORE: 0
        });
    }

}
