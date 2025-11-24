// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { ChainIdUtils, ChainId } from "src/libraries/helpers/ChainId.sol";

import { CastingHelpers } from "src/libraries/helpers/CastingHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface AutoLineLike {
    function exec(bytes32) external;
}

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
}

contract GroveEthereum_20251211_Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant MAINNET_STAC_DEPOSIT_WALLET = 0x51e4C4A356784D0B3b698BFB277C626b2b9fe178;
    address internal constant MAINNET_STAC_REDEEM_WALLET  = 0xbb543C77436645C8b95B64eEc39E3C0d48D4842b;
    address internal constant MAINNET_STAC                = 0x51C2d74017390CbBd30550179A16A1c28F7210fc;

    address internal constant MAINNET_GALAXY_DEPOSIT_WALLET = 0x2E3A11807B94E689387f60CD4BF52A56857f2eDC;

    address internal constant MAINNET_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBEEf2B5FD3D94469b7782aeBe6364E6e6FB1B709;

    address internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT = 0xBeEf2d50B428675a1921bC6bBF4bfb9D8cF1461A;

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

    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT  = 20_000_000e6;
    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint256 internal constant BASE_CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant BASE_CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    constructor() {
        id = "20251211";
    }

    function setUp() public {
        setupDomains("2025-11-23T12:00:00Z");

        deployPayloads();

        // Warp to ensure all rate limits and autoline cooldown are reset
        vm.warp(block.timestamp + 1 days);
        AutoLineLike(Ethereum.AUTO_LINE).exec(GROVE_ALLOCATOR_ILK);
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

    function test_ETHEREUM_onboardCctpTransfersToBase() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 generalCctpKey  = MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 baseCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        _assertUnlimitedRateLimit(generalCctpKey); // Set in the GroveEthereum_20250807 proposal
        _assertRateLimit(baseCctpKey, 0, 0);

        assertEq(MainnetController(Ethereum.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE), bytes32(0));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(baseCctpKey, MAINNET_CCTP_RATE_LIMIT_MAX, MAINNET_CCTP_RATE_LIMIT_SLOPE);

        assertEq(
            MainnetController(Ethereum.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY)
        );
    }

    function test_BASE_governanceDeployment() public onChain(ChainIdUtils.Base()) {
        _verifyForeignDomainExecutorDeployment({
            _executor : Base.GROVE_EXECUTOR,
            _receiver : Base.GROVE_RECEIVER,
            _deployer : DEPLOYER
        });
        _verifyArbitrumReceiverDeployment({
            _executor : Base.GROVE_EXECUTOR,
            _receiver : Base.GROVE_RECEIVER
        });
    }

    function test_BASE_almSystemDeployment() public onChain(ChainIdUtils.Base()) {
        _verifyForeignAlmSystemDeployment(
            AlmSystemContracts({
                admin      : Base.GROVE_EXECUTOR,
                proxy      : Base.ALM_PROXY,
                rateLimits : Base.ALM_RATE_LIMITS,
                controller : Base.ALM_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
                freezer  : Base.ALM_FREEZER,
                relayer  : Base.ALM_RELAYER
            }),
            ForeignAlmSystemDependencies({
                cctp : Base.CCTP_TOKEN_MESSENGER,
                psm  : Base.PSM3,
                usdc : Base.USDC
            })
        );
    }

    function test_BASE_initializeAlmSystem() public onChain(ChainIdUtils.Base()) {
        _testControllerUpgrade({
            oldController : address(0),
            newController : Base.ALM_CONTROLLER
        });
    }

    function test_BASE_onboardGroveXSteakhouseUsdcMorphoVault() public onChain(ChainIdUtils.Base()) {
        _testERC4626Onboarding({
            vault                 : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            expectedDepositAmount : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

    function test_BASE_onboardCctpTransfersToEthereum() public onChain(ChainIdUtils.Base()) {
        bytes32 generalCctpKey = ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 ethereumCctpKey = RateLimitHelpers.makeDomainKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        _assertRateLimit(generalCctpKey,  0, 0);
        _assertRateLimit(ethereumCctpKey, 0, 0);

        assertEq(ForeignController(Base.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM), bytes32(0));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(ethereumCctpKey, BASE_CCTP_RATE_LIMIT_MAX, BASE_CCTP_RATE_LIMIT_SLOPE);

        assertEq(
            ForeignController(Base.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
        );
    }

    function test_ETHEREUM_BASE_cctpTransferE2E() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        ChainId[] memory chains = new ChainId[](1);
        chains[0] = ChainIdUtils.Base();

        IERC20Like baseUsdc     = IERC20Like(Base.USDC);
        IERC20Like ethereumUsdc = IERC20Like(Ethereum.USDC);

        MainnetController mainnetController = MainnetController(Ethereum.ALM_CONTROLLER);
        ForeignController baseController    = ForeignController(Base.ALM_CONTROLLER);

        // --- Step 1: Mint and bridge 10m USDC to Base ---

        uint256 usdcAmount = 50_000_000e6;

        vm.startPrank(Ethereum.ALM_RELAYER);
        mainnetController.mintUSDS(usdcAmount * 1e12);
        mainnetController.swapUSDSToUSDC(usdcAmount);
        mainnetController.transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        selectChain(ChainIdUtils.Base());

        assertEq(baseUsdc.balanceOf(Base.ALM_PROXY), 0, "Base ALM proxy should have no USDC before message relay");

        _relayMessageOverBridges(chains);

        assertEq(baseUsdc.balanceOf(Base.ALM_PROXY), usdcAmount, "Base ALM proxy should have USDC after message relay");

        // --- Step 2: Bridge USDC back to mainnet and burn USDS

        vm.startPrank(Base.ALM_RELAYER);
        baseController.transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
        vm.stopPrank();

        assertEq(baseUsdc.balanceOf(Base.ALM_PROXY), 0, "Base ALM proxy should have no USDC after transfer");

        selectChain(ChainIdUtils.Ethereum());

        uint256 usdcPrevBalance = ethereumUsdc.balanceOf(Ethereum.ALM_PROXY);

        _relayMessageOverBridges(chains);

        assertEq(ethereumUsdc.balanceOf(Ethereum.ALM_PROXY), usdcPrevBalance + usdcAmount, "Ethereum ALM proxy should have USDC after message relay");

        vm.startPrank(Ethereum.ALM_RELAYER);
        mainnetController.swapUSDCToUSDS(usdcAmount);
        mainnetController.burnUSDS(usdcAmount * 1e12);
        vm.stopPrank();

        assertEq(ethereumUsdc.balanceOf(Ethereum.ALM_PROXY), usdcPrevBalance, "Ethereum ALM proxy should have no USDC after burn");
    }

}
