// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/MainnetControllerInit.sol";

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  August 7, 2025 Grove Ethereum Proposal
 * @notice TODO
 * @author Grove Labs
 * Forum : TODO
 * Vote  : TODO
 */
contract GroveEthereum_20250807 is GrovePayloadEthereum {

    address internal constant NEW_CENTRIFUGE_JTRSY_VAULT = 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A;
    address internal constant NEW_CENTRIFUGE_JAAA_VAULT  = 0x4880799eE5200fC58DA299e965df644fBf46780B;

    uint256 internal constant ZERO = 0;

    uint256 internal constant NEW_JTRSY_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant NEW_JTRSY_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_JAAA_RATE_LIMIT_MAX   = 100_000_000e6;
    uint256 internal constant NEW_JAAA_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    function _execute() internal override {
        _onboardCctpTransfersToAvalanche();
        _offboardOldCentrifugeJtrsy();
        _onboardNewCentrifugeJtrsy();
        _offboardOldCentrifugeJaaa();
        _onboardNewCentrifugeJaaa();
        _onboardEthena();
    }

    function _onboardCctpTransfersToAvalanche() internal {
        // TODO: Implement
    }

    function _offboardOldCentrifugeJtrsy() internal {
        bytes32 oldJtrsyDepositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_DEPOSIT(),
            Ethereum.CENTRIFUGE_JTRSY
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldJtrsyDepositKey,
            maxAmount : ZERO,
            slope     : ZERO
        });
    }

    function _onboardNewCentrifugeJtrsy() internal {
        _onboardERC7540Vault(
            NEW_CENTRIFUGE_JTRSY_VAULT,
            NEW_JTRSY_RATE_LIMIT_MAX,
            NEW_JTRSY_RATE_LIMIT_SLOPE
        );
    }

    function _offboardOldCentrifugeJaaa() internal {
        bytes32 oldJaaaDepositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_7540_DEPOSIT(),
            Ethereum.CENTRIFUGE_JAAA
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : oldJaaaDepositKey,
            maxAmount : ZERO,
            slope     : ZERO
        });
    }

    function _onboardNewCentrifugeJaaa() internal {
        _onboardERC7540Vault(
            NEW_CENTRIFUGE_JAAA_VAULT,
            NEW_JAAA_RATE_LIMIT_MAX,
            NEW_JAAA_RATE_LIMIT_SLOPE
        );
    }

    function _onboardEthena() internal {
        // USDe mint
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDE_MINT(),
            maxAmount : 250_000_000e6,
            slope     : 100_000_000e6 / uint256(1 days)
        });

        // USDe burn
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDE_BURN(),
            maxAmount : 500_000_000e18,
            slope     : 200_000_000e18 / uint256(1 days)
        });

        // sUSDe deposit (no need for withdrawal because of cooldown)
        bytes32 susdeDepositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_4626_DEPOSIT(),
            Ethereum.SUSDE
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : susdeDepositKey,
            maxAmount : 250_000_000e18,
            slope     : 100_000_000e18 / uint256(1 days)
        });

        // Cooldown
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setUnlimitedRateLimitData(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_SUSDE_COOLDOWN()
        );
    }

}
