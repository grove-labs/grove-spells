// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Base } from "lib/grove-address-registry/src/Base.sol";

import { GrovePayloadBase } from "src/libraries/payloads/GrovePayloadBase.sol";

/**
 * @title  October 8, 2026 Grove Base Proposal
 * @author Grove Labs
 */
contract GroveBase_20261008 is GrovePayloadBase {

    function execute() external {
        // [Base] Item 7: set the Steakhouse Prime USDC deposit rate limit to 0.
        //   Forum : TODO
        _offboardSteakhousePrimeUsdcDepositRateLimit();

        // [Base] Item 8: set the Grove x Steakhouse USDC High Yield Vault V1.1 deposit rate limit to 0.
        //   Forum : TODO
        _offboardGroveXSteakhouseUsdcDepositRateLimit();
    }

    function _offboardSteakhousePrimeUsdcDepositRateLimit() internal {
        _offboardERC4626VaultDeposits({
            vault         : Base.STEAKHOUSE_PRIME_INSTANT_V2_MORPHO_VAULT
        //  == OFFBOARDED ==
        //  depositMax    : 0           BEFORE: 20_000_000e6
        //  depositSlope  : 0           BEFORE: 20_000_000e6 / 1 days
        //  == PRESERVED ==
        //  withdrawMax   : unlimited   BEFORE: unlimited
        //  withdrawSlope : 0           BEFORE: 0
        });
    }

    function _offboardGroveXSteakhouseUsdcDepositRateLimit() internal {
        _offboardERC4626VaultDeposits({
            vault         : Base.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT
        //  == OFFBOARDED ==
        //  depositMax    : 0           BEFORE: 20_000_000e6
        //  depositSlope  : 0           BEFORE: 20_000_000e6 / 1 days
        //  == PRESERVED ==
        //  withdrawMax   : unlimited   BEFORE: unlimited
        //  withdrawSlope : 0           BEFORE: 0
        });
    }

}
