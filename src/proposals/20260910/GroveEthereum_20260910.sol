// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IGroveBasinLike {
    function grantRole(bytes32 role, address account) external;
}

/**
 * @title  September 10, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260910 is GrovePayloadEthereum {

    address internal constant BUIDL_I_GROVE_BASIN = 0xf1615aC3181a4a28D35fB2b9cea84dd4a199B9D7;

    address internal constant CENTRIFUGE_OPERATOR_WALLET = 0x7Bf090B97f896fB77e852CC98aa52A8Cb7DC02eC;

    address internal constant GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT = 0xbeef05061FE51eA482BD1b68041353490b3a5934;

    bytes32 internal constant REDEEMER_ROLE = keccak256("REDEEMER_ROLE");

    function _execute() internal override {
        // [Ethereum] Item 1: onboard the BUIDL-I Tokenized Treasury (Basin) Instance.
        //   Forum : TODO
        _onboardBuidlIBasin();

        // [Ethereum] Item 2: grant REDEEMER_ROLE on the JTRSY Basin Instance to the Centrifuge operator wallet.
        //   Forum : TODO
        _grantJtrsyBasinRedeemerRole();

        // [Ethereum] Item 3: onboard the Grove x Steakhouse USDG Morpho vault.
        //   Forum : TODO
        _onboardGroveXSteakhouseUsdgMorphoVault();
    }

    function _onboardBuidlIBasin() internal {
        _setBasinPauRateLimits({
            rateLimits   : Ethereum.PAU_RATE_LIMITS,
            basin        : BUIDL_I_GROVE_BASIN,
            depositMax   : 5_000_000e18,                  // BEFORE: 0
            depositSlope : 5_000_000e18 / uint256(1 days) // BEFORE: 0
        });
    }

    function _grantJtrsyBasinRedeemerRole() internal {
        IGroveBasinLike(Ethereum.JTRSY_GROVE_BASIN).grantRole(REDEEMER_ROLE, CENTRIFUGE_OPERATOR_WALLET);
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
