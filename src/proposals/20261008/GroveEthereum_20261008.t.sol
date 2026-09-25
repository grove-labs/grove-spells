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
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
    function getThreshold() external view returns (uint256);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);
    function isOwner(address owner) external view returns (bool);
    function nonce() external view returns (uint256);
}

interface IVaultV2Like {
    function curator() external view returns (address);
    function isSentinel(address account) external view returns (bool);
    function owner() external view returns (address);
}

contract GroveEthereum_20261008_Test is GroveTestBase {

    address internal constant VAULT_OWNER_SAFE        = 0xD700038b3f8d2F1a8193F35d7dD25c02e7155427;
    bytes32 internal constant VAULT_MIGRATION_TX_HASH = 0x8856a205b4c0b0eac9dad69a0c756eb7effa1d42134fccbc66dda1e8a85c32d8;

    address internal constant MULTI_SEND_CALL_ONLY = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;

    uint8 internal constant SAFE_OPERATION_DELEGATECALL = 1;

    address internal constant VAULT_MIGRATION_CURATOR   = 0x622E19d6903BD4507cfc70b31d5B99535114C0FC;
    address internal constant VAULT_MIGRATION_OPS_OWNER = 0x0A0e559bc3b0950a7e448F0d4894db195b9cf8DD;
    address internal constant VAULT_MIGRATION_SENTINEL  = 0xB597026150552bB3F6092aC685A2241C5FA77Ed0;

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

    function test_ETHEREUM_executeVaultMigration() public onChain(ChainIdUtils.Ethereum()) {
        ISafeLike safe = ISafeLike(VAULT_OWNER_SAFE);

        address[3] memory vaults = [
            Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT,
            Ethereum.GROVE_X_STEAKHOUSE_AUSD_V2_MORPHO_VAULT,
            Ethereum.GROVE_X_STEAKHOUSE_RLUSD_V2_MORPHO_VAULT
        ];

        bytes memory migrationCalldata = _vaultMigrationCalldata();

        bytes32 migrationHash = safe.getTransactionHash({
            to             : MULTI_SEND_CALL_ONLY,
            value          : 0,
            data           : migrationCalldata,
            operation      : SAFE_OPERATION_DELEGATECALL,
            safeTxGas      : 0,
            baseGas        : 0,
            gasPrice       : 0,
            gasToken       : address(0),
            refundReceiver : address(0),
            _nonce         : 0
        });

        assertEq(migrationHash, VAULT_MIGRATION_TX_HASH, "migration-tx-hash-mismatch");

        assertEq(safe.approvedHashes(VAULT_MIGRATION_OPS_OWNER, VAULT_MIGRATION_TX_HASH), 1, "ops-owner-approval-missing");
        assertEq(safe.nonce(), 0, "safe-nonce-changed");

        for (uint256 i; i < vaults.length; i++) {
            assertEq(IVaultV2Like(vaults[i]).owner(), VAULT_OWNER_SAFE, "vault-owner-changed");
            assertNotEq(IVaultV2Like(vaults[i]).curator(), VAULT_MIGRATION_CURATOR, "curator-already-migrated");
            assertTrue(IVaultV2Like(vaults[i]).isSentinel(Ethereum.GROVE_PROXY),      "sub-proxy-not-sentinel");
            assertFalse(IVaultV2Like(vaults[i]).isSentinel(VAULT_MIGRATION_SENTINEL), "sentinel-already-set");
        }

        executeAllPayloadsAndBridges();

        // Safe checks approved-hash signatures in ascending owner address order.
        safe.execTransaction({
            to             : MULTI_SEND_CALL_ONLY,
            value          : 0,
            data           : migrationCalldata,
            operation      : SAFE_OPERATION_DELEGATECALL,
            safeTxGas      : 0,
            baseGas        : 0,
            gasPrice       : 0,
            gasToken       : address(0),
            refundReceiver : address(0),
            signatures     : abi.encodePacked(
                _approvedHashSignature(VAULT_MIGRATION_OPS_OWNER),
                _approvedHashSignature(Ethereum.GROVE_PROXY)
            )
        });

        assertEq(safe.nonce(), 1, "safe-nonce-not-incremented");

        for (uint256 i; i < vaults.length; i++) {
            assertEq(IVaultV2Like(vaults[i]).owner(),   Ethereum.GROVE_PROXY,    "vault-owner-not-migrated");
            assertEq(IVaultV2Like(vaults[i]).curator(), VAULT_MIGRATION_CURATOR, "curator-not-migrated");
            assertFalse(IVaultV2Like(vaults[i]).isSentinel(Ethereum.GROVE_PROXY),    "sub-proxy-still-sentinel");
            assertTrue(IVaultV2Like(vaults[i]).isSentinel(VAULT_MIGRATION_SENTINEL), "sentinel-not-set");
        }
    }

    function test_ETHEREUM_offboardGroveXSteakhouseUsdcDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626DepositsOffboarding(Ethereum.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT);
    }

    function test_ETHEREUM_offboardSteakhousePyusdDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626DepositsOffboarding(Ethereum.STEAKHOUSE_PYUSD_MORPHO_VAULT);
    }

    function test_ETHEREUM_offboardSentoraPyusdMainDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626DepositsOffboarding(Ethereum.SENTORA_PYUSD_MAIN_V2_MORPHO_VAULT);
    }

    function test_ETHEREUM_offboardSentoraRlusdMainDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626DepositsOffboarding(Ethereum.SENTORA_RLUSD_MAIN_V2_MORPHO_VAULT);
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
        _testERC4626DepositsOffboarding(Base.STEAKHOUSE_PRIME_INSTANT_V2_MORPHO_VAULT);
    }

    function test_BASE_offboardGroveXSteakhouseUsdcDepositRateLimit() public onChain(ChainIdUtils.Base()) {
        _testERC4626DepositsOffboarding(Base.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT);
    }

    function _vaultMigrationCalldata() internal pure returns (bytes memory) {
        address[3] memory vaults = [
            Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT,
            Ethereum.GROVE_X_STEAKHOUSE_AUSD_V2_MORPHO_VAULT,
            Ethereum.GROVE_X_STEAKHOUSE_RLUSD_V2_MORPHO_VAULT
        ];

        bytes memory batch;

        for (uint256 i; i < vaults.length; i++) {
            batch = abi.encodePacked(
                batch,
                _multiSendCall(vaults[i], abi.encodeWithSignature("setCurator(address)",         VAULT_MIGRATION_CURATOR)),
                _multiSendCall(vaults[i], abi.encodeWithSignature("setIsSentinel(address,bool)", VAULT_MIGRATION_SENTINEL, true)),
                _multiSendCall(vaults[i], abi.encodeWithSignature("setIsSentinel(address,bool)", Ethereum.GROVE_PROXY, false)),
                _multiSendCall(vaults[i], abi.encodeWithSignature("setOwner(address)",           Ethereum.GROVE_PROXY))
            );
        }

        return abi.encodeWithSignature("multiSend(bytes)", batch);
    }

    function _multiSendCall(address target, bytes memory data) internal pure returns (bytes memory) {
        // MultiSend packs each call as operation (0 = CALL), target, value, data length, data.
        return abi.encodePacked(uint8(0), target, uint256(0), data.length, data);
    }

    function _approvedHashSignature(address owner) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(uint160(owner))), bytes32(0), uint8(1));
    }

}
