// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface AutoLineLike {
    function exec(bytes32) external;
}

interface ISubProxyLike {
    function rely(address) external;
}

contract GroveEthereum_20251211_Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant MAINNET_STAC_DEPOSIT_WALLET = 0x51e4C4A356784D0B3b698BFB277C626b2b9fe178;
    address internal constant MAINNET_STAC_REDEEM_WALLET  = 0xbb543C77436645C8b95B64eEc39E3C0d48D4842b;
    address internal constant MAINNET_STAC                = 0x51C2d74017390CbBd30550179A16A1c28F7210fc;

    address internal constant MAINNET_GALAXY_DEPOSIT_WALLET = 0x2E3A11807B94E689387f60CD4BF52A56857f2eDC;

    address internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBEEf2B5FD3D94469b7782aeBe6364E6e6FB1B709;

    uint256 internal constant MAINNET_STAC_DEPOSIT_MAX         = 50_000_000e6;
    uint256 internal constant MAINNET_STAC_DEPOSIT_SLOPE       = 50_000_000e6 / uint256(1 days);
    uint256 internal constant MAINNET_STAC_TEST_DEPOSIT_AMOUNT = 50_000_000e6;
    uint256 internal constant MAINNET_STAC_TEST_REDEEM_AMOUNT  = 50_000_000e6;

    uint256 internal constant MAINNET_GALAXY_DEPOSIT_MAX         = 50_000_000e6;
    uint256 internal constant MAINNET_GALAXY_DEPOSIT_SLOPE       = 50_000_000e6 / uint256(1 days);
    uint256 internal constant MAINNET_GALAXY_TEST_DEPOSIT_AMOUNT = 50_000_000e6;

    uint256 internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT  = 20_000_000e6;
    uint256 internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint256 internal constant MAINNET_CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant MAINNET_CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    constructor() {
        id = "20251211";
    }

    function setUp() public {
        setupDomains("2025-11-23T12:00:00Z");

        deployPayloads();

        // Warp to ensure all rate limits and autoline cooldown are reset
        vm.warp(block.timestamp + 1 days);
        AutoLineLike(Ethereum.AUTO_LINE).exec(GROVE_ALLOCATOR_ILK);

        // One-time simplified onboarding of StarGuard to the proxy
        vm.prank(Ethereum.PAUSE_PROXY);
        ISubProxyLike(Ethereum.GROVE_PROXY).rely(Ethereum.GROVE_STAR_GUARD);
    }

    function test_ETHEREUM_onboardSecuritizeStacDeposits() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : MAINNET_STAC_DEPOSIT_WALLET,
            expectedDepositAmount : MAINNET_STAC_TEST_DEPOSIT_AMOUNT,
            depositMax            : MAINNET_STAC_DEPOSIT_MAX,
            depositSlope          : MAINNET_STAC_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardSecuritizeStacRedemptions() public onChain(ChainIdUtils.Ethereum()) {
        _testUnlimitedDirectTokenTransferOnboarding({
            token                 : MAINNET_STAC,
            destination           : MAINNET_STAC_REDEEM_WALLET,
            expectedDepositAmount : MAINNET_STAC_TEST_REDEEM_AMOUNT
        });
    }

    function test_ETHEREUM_onboardGalaxyArchClosDeposits() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : MAINNET_GALAXY_DEPOSIT_WALLET,
            expectedDepositAmount : MAINNET_GALAXY_TEST_DEPOSIT_AMOUNT,
            depositMax            : MAINNET_GALAXY_DEPOSIT_MAX,
            depositSlope          : MAINNET_GALAXY_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardGroveXSteakhouseUsdcMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            expectedDepositAmount : MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

}
