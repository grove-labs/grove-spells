// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { AllocatorBuffer } from "lib/dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorVault }  from "lib/dss-allocator/src/AllocatorVault.sol";

import { LZForwarder } from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

/**
 * @title  May 7, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260507 is GrovePayloadEthereum {

    address internal constant GROVE_X_STEAKHOUSE_RLUSD_V2 = 0xBeEff4fD39F8e48b6a6e475445D650cb11e9599F;

    address internal constant GROVE_FOUNDATION = 0xE3EC4CC359E68c9dCE15Bf667b1aD37Df54a5a42;

    uint256 internal constant GROVE_FOUNDATION_GRANT_AMOUNT = 800_000e18;

    // TODO: Set Avalanche payload address before deployment
    // constructor() {
    //     PAYLOAD_AVALANCHE = address(0);
    // }

    function _execute() internal override {
        // [Ethereum] Onboard Tokenized Treasury Instance — Initial Deposit (JTRSY)
        //   Forum : TODO: Add forum link
        _onboardTokenizedTreasuryInstanceJtrsy();

        // [Ethereum] Onboard Grove x Steakhouse RLUSD Morpho Vault V2
        //   Forum : TODO: Add forum link
        _onboardGroveXSteakhouseRlusdMorphoVaultV2();

        // [Ethereum] Grove Treasury — Monthly Grant for Grove Foundation
        //   Forum : TODO: Add forum link
        _transferMonthlyGrantToGroveFoundation();

        // [Ethereum + Avalanche] Upgrade Governance Relay to LayerZero V2
        //   Forum : TODO: Add forum link
        _configureLZGovernanceSender();
    }

    function _onboardTokenizedTreasuryInstanceJtrsy() internal {
        // TODO: Implement JTRSY instance onboarding (pending audit completion and deployment)
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

    function _configureLZGovernanceSender() internal {
        address[] memory dvns = new address[](2);
        dvns[0] = LZForwarder.LAYER_ZERO_DVN_ETHEREUM;
        dvns[1] = LZForwarder.NETHERMIND_DVN_ETHEREUM;

        LZForwarder.configureSender({
            endpoint  : LZForwarder.ENDPOINT_ETHEREUM,
            remoteEid : LZForwarder.ENDPOINT_ID_AVALANCHE,
            dvns      : dvns,
            executor  : LZForwarder.EXECUTOR_ETHEREUM
        });
    }

    function _transferMonthlyGrantToGroveFoundation() internal {
        IERC20(Ethereum.USDS).transfer(GROVE_FOUNDATION, GROVE_FOUNDATION_GRANT_AMOUNT);
    }

}
