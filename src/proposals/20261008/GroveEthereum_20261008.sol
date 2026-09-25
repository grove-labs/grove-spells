// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface ISafeLike {
    function approveHash(bytes32 hashToApprove) external;
}

/**
 * @title  October 8, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20261008 is GrovePayloadEthereum {

    address internal constant VAULT_OWNER_SAFE        = 0xD700038b3f8d2F1a8193F35d7dD25c02e7155427;
    bytes32 internal constant VAULT_MIGRATION_TX_HASH = 0x8856a205b4c0b0eac9dad69a0c756eb7effa1d42134fccbc66dda1e8a85c32d8;

    address internal constant GROVE_X_STEAKHOUSE_PYUSD_V2_MORPHO_VAULT = 0xbeef08Db223ad823164A4B13CBD6bd8b5d507b41;

    constructor() {
        PAYLOAD_BASE = address(0); // TODO: set after foreign payload deploy
    }

    function _execute() internal override {
        // [Ethereum] Item 1: approve the Safe transaction migrating the USDC, AUSD and RLUSD Vault V2 vaults.
        //   Forum : https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255
        _approveVaultMigrationSafeTransaction();

        // [Ethereum] Item 2: set the Grove x Steakhouse USDC High Yield Vault V1.1 deposit rate limit to 0.
        //   Forum : https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255
        _offboardGroveXSteakhouseUsdcDepositRateLimit();

        // [Ethereum] Item 3: set the Steakhouse High Yield Instant (PYUSD) deposit rate limit to 0.
        //   Forum : https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255
        _offboardSteakhousePyusdDepositRateLimit();

        // [Ethereum] Item 4: set the Paypal USD Main (Sentora) deposit rate limit to 0.
        //   Forum : https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255
        _offboardSentoraPyusdMainDepositRateLimit();

        // [Ethereum] Item 5: set the Sentora RLUSD Main deposit rate limit to 0.
        //   Forum : https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255
        _offboardSentoraRlusdMainDepositRateLimit();

        // [Ethereum] Item 6: onboard the Grove x Steakhouse PYUSD Morpho Vault V2.
        //   Forum : https://forum.skyeco.com/t/october-8-2026-proposed-changes-to-grove-for-upcoming-spell/28255
        _onboardGroveXSteakhousePyusdV2MorphoVault();
    }

    function _approveVaultMigrationSafeTransaction() internal {
        // Steakhouse already approved, so this is the second of two and any account can then execute it.
        ISafeLike(VAULT_OWNER_SAFE).approveHash(VAULT_MIGRATION_TX_HASH);
    }

    function _offboardGroveXSteakhouseUsdcDepositRateLimit() internal {
        _offboardERC4626VaultDeposits({
            vault         : Ethereum.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT
        //  == OFFBOARDED ==
        //  depositMax    : 0           BEFORE: 20_000_000e6
        //  depositSlope  : 0           BEFORE: 20_000_000e6 / 1 days
        //  == PRESERVED ==
        //  withdrawMax   : unlimited   BEFORE: unlimited
        //  withdrawSlope : 0           BEFORE: 0
        });
    }

    function _offboardSteakhousePyusdDepositRateLimit() internal {
        _offboardERC4626VaultDeposits({
            vault         : Ethereum.STEAKHOUSE_PYUSD_MORPHO_VAULT
        //  == OFFBOARDED ==
        //  depositMax    : 0           BEFORE: 20_000_000e6
        //  depositSlope  : 0           BEFORE: 20_000_000e6 / 1 days
        //  == PRESERVED ==
        //  withdrawMax   : unlimited   BEFORE: unlimited
        //  withdrawSlope : 0           BEFORE: 0
        });
    }

    function _offboardSentoraPyusdMainDepositRateLimit() internal {
        _offboardERC4626VaultDeposits({
            vault         : Ethereum.SENTORA_PYUSD_MAIN_V2_MORPHO_VAULT
        //  == OFFBOARDED ==
        //  depositMax    : 0           BEFORE: 50_000_000e6
        //  depositSlope  : 0           BEFORE: 50_000_000e6 / 1 days
        //  == PRESERVED ==
        //  withdrawMax   : unlimited   BEFORE: unlimited
        //  withdrawSlope : 0           BEFORE: 0
        });
    }

    function _offboardSentoraRlusdMainDepositRateLimit() internal {
        _offboardERC4626VaultDeposits({
            vault         : Ethereum.SENTORA_RLUSD_MAIN_V2_MORPHO_VAULT
        //  == OFFBOARDED ==
        //  depositMax    : 0           BEFORE: 50_000_000e18
        //  depositSlope  : 0           BEFORE: 50_000_000e18 / 1 days
        //  == PRESERVED ==
        //  withdrawMax   : unlimited   BEFORE: unlimited
        //  withdrawSlope : 0           BEFORE: 0
        });
    }

    function _onboardGroveXSteakhousePyusdV2MorphoVault() internal {
        _onboardERC4626Vault({
            vault             : GROVE_X_STEAKHOUSE_PYUSD_V2_MORPHO_VAULT,
            depositMax        : 20_000_000e6,                   // BEFORE: 0
            depositSlope      : 20_000_000e6 / uint256(1 days), // BEFORE: 0
            shareUnit         : 1e18,                           // BEFORE: 0
            maxAssetsPerShare : 4e6                             // BEFORE: 0
        //  withdrawMax       : unlimited                          BEFORE: 0
        //  withdrawSlope     : 0                                  BEFORE: 0
        });
    }

}
