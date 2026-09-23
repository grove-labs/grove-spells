// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { Base }     from "lib/grove-address-registry/src/Base.sol";
import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface ISafeLike {
    function approvedHashes(address owner, bytes32 hashToApprove) external view returns (uint256);
    function getThreshold() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function nonce() external view returns (uint256);
}

interface IVaultV2Like {
    function owner() external view returns (address);
}

contract GroveEthereum_20261008_Test is GroveTestBase {

    address internal constant VAULT_OWNER_SAFE        = 0xD700038b3f8d2F1a8193F35d7dD25c02e7155427;
    bytes32 internal constant VAULT_MIGRATION_TX_HASH = 0x8856a205b4c0b0eac9dad69a0c756eb7effa1d42134fccbc66dda1e8a85c32d8;

    address internal constant GROVE_X_STEAKHOUSE_PYUSD_V2_MORPHO_VAULT = 0xbeef08Db223ad823164A4B13CBD6bd8b5d507b41;

    constructor() {
        id = "20261008";
    }

    function setUp() public {
        setupDomains("2026-09-22T10:21:38Z");

        deployPayloads();
    }

    function test_ETHEREUM_approveVaultMigrationSafeTransaction() public onChain(ChainIdUtils.Ethereum()) {
        ISafeLike safe = ISafeLike(VAULT_OWNER_SAFE);

        assertEq(IVaultV2Like(Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT).owner(), VAULT_OWNER_SAFE, "usdc-vault-owner-changed");
        assertEq(IVaultV2Like(Ethereum.GROVE_X_STEAKHOUSE_AUSD_V2_MORPHO_VAULT).owner(),    VAULT_OWNER_SAFE, "ausd-vault-owner-changed");
        assertEq(IVaultV2Like(Ethereum.GROVE_X_STEAKHOUSE_RLUSD_V2_MORPHO_VAULT).owner(),   VAULT_OWNER_SAFE, "rlusd-vault-owner-changed");

        assertTrue(safe.isOwner(Ethereum.GROVE_PROXY), "sub-proxy-not-safe-owner");
        assertEq(safe.getThreshold(), 2, "safe-threshold-changed");
        assertEq(safe.nonce(),        0, "safe-nonce-changed");

        assertEq(safe.approvedHashes(Ethereum.GROVE_PROXY, VAULT_MIGRATION_TX_HASH), 0, "hash-already-approved");

        executeAllPayloadsAndBridges();

        assertEq(safe.approvedHashes(Ethereum.GROVE_PROXY, VAULT_MIGRATION_TX_HASH), 1, "hash-not-approved");

        // The spell only approves; execTransaction stays outside it, so no vault role changes here.
        assertEq(safe.nonce(), 0, "safe-transaction-executed-by-spell");
    }

    function test_ETHEREUM_offboardGroveXSteakhouseUsdcDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626DepositsOffboarding({
            vault              : Ethereum.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            expectedDepositKey : 0x82fb6a87781d1c18617960e9528d0633bfbc534f5ae8109347f10bb49a2f4f19,
            depositMax         : 20_000_000e6,
            depositSlope       : 20_000_000e6 / uint256(1 days),
            depositAttempt     : 1e6
        });
    }

    function test_ETHEREUM_offboardSteakhousePyusdDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626DepositsOffboarding({
            vault              : Ethereum.STEAKHOUSE_PYUSD_MORPHO_VAULT,
            expectedDepositKey : 0xfc4e1f8ba7b0389a287411c3f6b97cc0ec60fb2816bfaa31e12a21561486321a,
            depositMax         : 20_000_000e6,
            depositSlope       : 20_000_000e6 / uint256(1 days),
            depositAttempt     : 1e6
        });
    }

    function test_ETHEREUM_offboardSentoraPyusdMainDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626DepositsOffboarding({
            vault              : Ethereum.SENTORA_PYUSD_MAIN_V2_MORPHO_VAULT,
            expectedDepositKey : 0x4dc0c7cd471560aa12324cb36f720d7d301ef230d3ae772ae07b681725ae7b66,
            depositMax         : 50_000_000e6,
            depositSlope       : 50_000_000e6 / uint256(1 days),
            depositAttempt     : 1e6
        });
    }

    function test_ETHEREUM_offboardSentoraRlusdMainDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626DepositsOffboarding({
            vault              : Ethereum.SENTORA_RLUSD_MAIN_V2_MORPHO_VAULT,
            expectedDepositKey : 0x944bbb34c3717aacc72419f43d62f5a01d2ebd7a9157ba9975fd7d971deb803f,
            depositMax         : 50_000_000e18,
            depositSlope       : 50_000_000e18 / uint256(1 days),
            depositAttempt     : 1e18
        });
    }

    function test_ETHEREUM_onboardGroveXSteakhousePyusdV2MorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        assertEq(IERC4626(GROVE_X_STEAKHOUSE_PYUSD_V2_MORPHO_VAULT).asset(), Ethereum.PYUSD, "vault-asset-not-pyusd");

        assertEq(IERC20(Ethereum.PYUSD).decimals(),                             6,  "pyusd-decimals-changed");
        assertEq(IERC4626(GROVE_X_STEAKHOUSE_PYUSD_V2_MORPHO_VAULT).decimals(), 18, "vault-decimals-changed");

        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_PYUSD_V2_MORPHO_VAULT,
            expectedDepositAmount : 20_000_000e6,
            depositMax            : 20_000_000e6,
            depositSlope          : 20_000_000e6 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 4e6
        });
    }

    function test_BASE_offboardSteakhousePrimeUsdcDepositRateLimit() public onChain(ChainIdUtils.Base()) {
        _testERC4626DepositsOffboarding({
            vault              : Base.STEAKHOUSE_PRIME_INSTANT_V2_MORPHO_VAULT,
            expectedDepositKey : 0xcc33156879fb03deee37b5ff243fa9afa95b94d13a2ab710f8096c0b5f053f3b,
            depositMax         : 20_000_000e6,
            depositSlope       : 20_000_000e6 / uint256(1 days),
            depositAttempt     : 1e6
        });
    }

    function test_BASE_offboardGroveXSteakhouseUsdcDepositRateLimit() public onChain(ChainIdUtils.Base()) {
        _testERC4626DepositsOffboarding({
            vault              : Base.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            expectedDepositKey : 0xb5c3e377398c99e28d39340657bbc979bef79e01e2af3d0ff742e30722cd0d5a,
            depositMax         : 20_000_000e6,
            depositSlope       : 20_000_000e6 / uint256(1 days),
            depositAttempt     : 1e6
        });
    }

}
