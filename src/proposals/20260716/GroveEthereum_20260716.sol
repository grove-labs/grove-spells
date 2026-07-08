// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum }                   from "lib/grove-address-registry/src/Ethereum.sol";
import { Ethereum as SparkContracts } from "lib/spark-address-registry/src/Ethereum.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  July 16, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260716 is GrovePayloadEthereum {

    // Paxos-controlled USDC deposit wallet on Mainnet (Item 1c, Mainnet -> Robinhood).
    address internal constant PAXOS_USDC_DEPOSIT_WALLET = 0x8C0A9E5939B97979f85d9aDA3d983C6E713Cc2dB;

    constructor() {
        PAYLOAD_ROBINHOOD = 0x247B2766780Ee746650Dea7a2D449BBB56498eac;
    }

    function _execute() internal override {
        // [Ethereum] Item 1c (Mainnet -> Robinhood): Paxos USDC bridge rate limit.
        //   Forum : https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-grove-for-upcoming-spell/28024#p-106736-proposed-actions-16
        _onboardPaxosUsdcBridgeRateLimit();

        // [Ethereum] Item 3: transfer all syrupUSDC held by the ALM Proxy to the Spark ALM Proxy.
        //   Forum : https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-grove-for-upcoming-spell/28024#p-106736-proposed-actions-16
        _transferSyrupUsdcToSpark();
    }

    function _onboardPaxosUsdcBridgeRateLimit() internal {
        bytes32 transferKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            PAXOS_USDC_DEPOSIT_WALLET
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(
            transferKey,
            50_000_000e6,                   // BEFORE: 0
            50_000_000e6 / uint256(1 days)  // BEFORE: 0
        );
    }

    function _transferSyrupUsdcToSpark() internal {
        _transferAssetFromAlmProxy(
            Ethereum.MAPLE_SYRUP_USDC,
            SparkContracts.ALM_PROXY,
            IERC20(Ethereum.MAPLE_SYRUP_USDC).balanceOf(Ethereum.ALM_PROXY)
        );
    }

}
