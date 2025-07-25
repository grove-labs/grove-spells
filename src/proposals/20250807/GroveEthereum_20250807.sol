// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { GrovePayloadEthereum } from "src/libraries/GrovePayloadEthereum.sol";

/**
 * @title  August 7, 2025 Grove Ethereum Proposal
 * @notice TODO
 * @author Grove Labs
 * Forum : TODO
 * Vote  : TODO
 */
contract GroveEthereum_20250807 is GrovePayloadEthereum {

    address internal constant NEW_ALM_CONTROLLER = 0x28170D5084cc3cEbFC5f21f30DB076342716f30C;

    function _execute() internal override {
        _upgradeController();
        _migrateCentrifugeJtrsy();
        _migrateCentrifugeJaaa();
        _onboardCentrifugeCrosschainTransfers();
        _onboardStakedUSDCVault();
        _onboardSparkLend();
        _onboardEthena();
    }

    function _upgradeController() internal {
        // TODO: Implement
    }

    function _migrateCentrifugeJtrsy() internal {
        // TODO: Implement
    }

    function _migrateCentrifugeJaaa() internal {
        // TODO: Implement
    }

    function _onboardCentrifugeCrosschainTransfers() internal {
        // TODO: Implement
    }

    function _onboardStakedUSDCVault() internal {
        // TODO: Implement
    }

    function _onboardSparkLend() internal {
        // TODO: Implement
    }

    function _onboardEthena() internal {
        // USDe mint/burn
        RateLimitHelpers.setRateLimitData(
            MainnetController(NEW_ALM_CONTROLLER).LIMIT_USDE_MINT(),
            Ethereum.ALM_RATE_LIMITS,
            IRateLimits.RateLimitData({
                maxAmount : 250_000_000e6,
                slope     : 100_000_000e6 / uint256(1 days)
            }),
            "ethenaMintLimit",
            6
        );
        RateLimitHelpers.setRateLimitData(
            MainnetController(NEW_ALM_CONTROLLER).LIMIT_USDE_BURN(),
            Ethereum.ALM_RATE_LIMITS,
            IRateLimits.RateLimitData({
                maxAmount : 500_000_000e18,
                slope     : 200_000_000e18 / uint256(1 days)
            }),
            "ethenaBurnLimit",
            18
        );

        // sUSDe deposit (no need for withdrawal because of cooldown)
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                MainnetController(NEW_ALM_CONTROLLER).LIMIT_4626_DEPOSIT(),
                Ethereum.SUSDE
            ),
            Ethereum.ALM_RATE_LIMITS,
            IRateLimits.RateLimitData({
                maxAmount : 250_000_000e18,
                slope     : 100_000_000e18 / uint256(1 days)
            }),
            "susdeDepositLimit",
            18
        );

        // Cooldown
        RateLimitHelpers.setRateLimitData(
            MainnetController(NEW_ALM_CONTROLLER).LIMIT_SUSDE_COOLDOWN(),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitHelpers.unlimitedRateLimit(),
            "susdeCooldownLimit",
            18
        );
    }

}
