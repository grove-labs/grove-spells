// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface AutoLineLike {
    function exec(bytes32) external;
}

contract GroveEthereum_20251211_Test is GroveTestBase {

    address internal constant ETHEREUM_PAYLOAD = 0x6772d7eaaB1c2e275f46B99D8cce8d470fA790Ab;

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant STAC_DEPOSIT_WALLET = 0x51e4C4A356784D0B3b698BFB277C626b2b9fe178;
    address internal constant STAC_REDEEM_WALLET  = 0xbb543C77436645C8b95B64eEc39E3C0d48D4842b;
    address internal constant STAC                = 0x51C2d74017390CbBd30550179A16A1c28F7210fc;

    address internal constant GALAXY_DEPOSIT_WALLET = 0x2E3A11807B94E689387f60CD4BF52A56857f2eDC;

    address internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBEEf2B5FD3D94469b7782aeBe6364E6e6FB1B709;

    address internal constant RIPPLE_RLUSD_USDC_MINT_BURN_WALLET = 0xD178a90C41ff3DcffbfDEF7De0BAF76Cbfe6a121;

    address internal constant AGORA_AUSD_USDC_MINT_WALLET = 0xfEa17E5f0e9bF5c86D5d553e2A074199F03B44E8;

    uint256 internal constant STAC_DEPOSIT_MAX         = 50_000_000e6;
    uint256 internal constant STAC_DEPOSIT_SLOPE       = 50_000_000e6 / uint256(1 days);
    uint256 internal constant STAC_TEST_DEPOSIT_AMOUNT = 50_000_000e6;
    uint256 internal constant STAC_TEST_REDEEM_AMOUNT  = 50_000_000e6;

    uint256 internal constant GALAXY_DEPOSIT_MAX         = 50_000_000e6;
    uint256 internal constant GALAXY_DEPOSIT_SLOPE       = 50_000_000e6 / uint256(1 days);
    uint256 internal constant GALAXY_TEST_DEPOSIT_AMOUNT = 50_000_000e6;

    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT  = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint256 internal constant RIPPLE_RLUSD_USDC_MINT_MAX         = 50_000_000e6;
    uint256 internal constant RIPPLE_RLUSD_USDC_MINT_SLOPE       = 50_000_000e6 / uint256(1 days);
    uint256 internal constant RIPPLE_RLUSD_USDC_TEST_MINT_AMOUNT = 50_000_000e6;

    uint256 internal constant RIPPLE_RLUSD_USDC_BURN_MAX         = 50_000_000e18;
    uint256 internal constant RIPPLE_RLUSD_USDC_BURN_SLOPE       = 50_000_000e18 / uint256(1 days);
    uint256 internal constant RIPPLE_RLUSD_USDC_TEST_BURN_AMOUNT = 50_000_000e18;

    uint256 internal constant AGORA_AUSD_USDC_MINT_MAX         = 50_000_000e6;
    uint256 internal constant AGORA_AUSD_USDC_MINT_SLOPE       = 50_000_000e6 / uint256(1 days);
    uint256 internal constant AGORA_AUSD_USDC_TEST_MINT_AMOUNT = 50_000_000e6;

    constructor() {
        id = "20251211";
    }

    function setUp() public {
        setupDomains("2025-12-14T12:00:00Z");

        chainData[ChainIdUtils.Ethereum()].payload = ETHEREUM_PAYLOAD;

        // Warp to ensure all rate limits and autoline cooldown are reset
        vm.warp(block.timestamp + 1 days);
        AutoLineLike(Ethereum.AUTO_LINE).exec(GROVE_ALLOCATOR_ILK);
    }

    function test_ETHEREUM_onboardSecuritizeStacDeposits() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : STAC_DEPOSIT_WALLET,
            expectedDepositAmount : STAC_TEST_DEPOSIT_AMOUNT,
            depositMax            : STAC_DEPOSIT_MAX,
            depositSlope          : STAC_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardSecuritizeStacRedemptions() public onChain(ChainIdUtils.Ethereum()) {
        _testUnlimitedDirectTokenTransferOnboarding({
            token                 : STAC,
            destination           : STAC_REDEEM_WALLET,
            expectedDepositAmount : STAC_TEST_REDEEM_AMOUNT
        });
    }

    function test_ETHEREUM_onboardGalaxyArchClosDeposits() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : GALAXY_DEPOSIT_WALLET,
            expectedDepositAmount : GALAXY_TEST_DEPOSIT_AMOUNT,
            depositMax            : GALAXY_DEPOSIT_MAX,
            depositSlope          : GALAXY_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardGroveXSteakhouseUsdcMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            expectedDepositAmount : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

    function test_ETHEREUM_onboardRippleRlusdMinting() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : RIPPLE_RLUSD_USDC_MINT_BURN_WALLET,
            expectedDepositAmount : RIPPLE_RLUSD_USDC_TEST_MINT_AMOUNT,
            depositMax            : RIPPLE_RLUSD_USDC_MINT_MAX,
            depositSlope          : RIPPLE_RLUSD_USDC_MINT_SLOPE
        });
    }

    function test_ETHEREUM_onboardRippleRlusdBurning() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectTokenTransferOnboarding({
            token                 : Ethereum.RLUSD,
            destination           : RIPPLE_RLUSD_USDC_MINT_BURN_WALLET,
            expectedDepositAmount : RIPPLE_RLUSD_USDC_TEST_BURN_AMOUNT,
            depositMax            : RIPPLE_RLUSD_USDC_BURN_MAX,
            depositSlope          : RIPPLE_RLUSD_USDC_BURN_SLOPE
        });
    }

    function test_ETHEREUM_onboardAgoraAusdMinting() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : AGORA_AUSD_USDC_MINT_WALLET,
            expectedDepositAmount : AGORA_AUSD_USDC_TEST_MINT_AMOUNT,
            depositMax            : AGORA_AUSD_USDC_MINT_MAX,
            depositSlope          : AGORA_AUSD_USDC_MINT_SLOPE
        });
    }

}
