// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  February 26, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260226 is GrovePayloadEthereum {

    address internal constant GALAXY_DEPOSIT_WALLET = 0x3E23311f9FF660E3c3d87E4b7c207b3c3D7e04f0;

    constructor() {
        PAYLOAD_BASE = address(0); // TODO: Set Base payload address after deployment
    }

    function _execute() internal override {
        // [Mainnet] Onboard Galaxy Deposit Address
        //   Forum : TODO
        _onboardGalaxyDeposits();
    }

    function _onboardGalaxyDeposits() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            GALAXY_DEPOSIT_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            depositKey,
            50_000_000e6,                  // BEFORE: 0
            50_000_000e6 / uint256(1 days) // BEFORE: 0
        );
    }

}
