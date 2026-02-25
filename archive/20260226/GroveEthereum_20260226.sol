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
        PAYLOAD_BASE = 0xfC3e2Fa0257d4454fFD6a079dd38f132b361AB9a;
    }

    function _execute() internal override {
        // [Ethereum] Onboard Galaxy Warehouse
        //   Forum : https://forum.sky.money/t/february-26-2026-proposed-changes-to-grove-for-upcoming-spell/27712#p-105710-h-2-ethereum-onboard-galaxy-warehouse-8
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
