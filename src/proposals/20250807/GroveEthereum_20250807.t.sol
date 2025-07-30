// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IALMProxy }   from "grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";
import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20250807Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant FAKE_PSM3_PLACEHOLDER = 0x00000000000000000000000000000000DeaDBeef;

    uint256 internal constant ZERO = 0;

    uint256 internal constant ETHEREUM_TO_AVALANCHE_CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant ETHEREUM_TO_AVALANCHE_CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant AVALANCHE_TO_ETHEREUM_CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant AVALANCHE_TO_ETHEREUM_CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant ETHENA_MINT_RATE_LIMIT_MAX   = 250_000_000e6;
    uint256 internal constant ETHENA_MINT_RATE_LIMIT_SLOPE = 100_000_000e6 / uint256(1 days);

    uint256 internal constant ETHENA_BURN_RATE_LIMIT_MAX   = 500_000_000e18;
    uint256 internal constant ETHENA_BURN_RATE_LIMIT_SLOPE = 200_000_000e18 / uint256(1 days);

    uint256 internal constant ETHENA_DEPOSIT_RATE_LIMIT_MAX   = 250_000_000e18;
    uint256 internal constant ETHENA_DEPOSIT_RATE_LIMIT_SLOPE = 100_000_000e18 / uint256(1 days);

    constructor() {
        id = "20250807";
    }

    function setUp() public {
        setupDomains("2025-07-28T16:15:00Z");
        deployPayloads();
    }

    function test_ETHEREUM_onboardCctpTransfersToAvalanche() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 generalCctpKey   = MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 avalancheCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE
        );

        _assertRateLimit(avalancheCctpKey, 0, 0);
        _assertRateLimit(generalCctpKey,   0, 0);

        assertEq(MainnetController(Ethereum.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE), bytes32(0));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(avalancheCctpKey, ETHEREUM_TO_AVALANCHE_CCTP_RATE_LIMIT_MAX, ETHEREUM_TO_AVALANCHE_CCTP_RATE_LIMIT_SLOPE);

        assertEq(MainnetController(Ethereum.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE), bytes32(uint256(uint160(Avalanche.ALM_PROXY))));
    }

    function test_ETHEREUM_onboardEthena() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        IRateLimits rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);

        bytes32 ethenaMintKey     = controller.LIMIT_USDE_MINT();
        bytes32 ethenaBurnKey     = controller.LIMIT_USDE_BURN();
        bytes32 susdeCooldownKey  = controller.LIMIT_SUSDE_COOLDOWN();

        bytes32 susdeDepositKey   = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_DEPOSIT(), Ethereum.SUSDE
        );

        bytes32 susdeWithdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_WITHDRAW(),
            Ethereum.SUSDE
        );

        // Ethena rate limits before should be zero
        _assertRateLimit(ethenaMintKey,    0, 0);
        _assertRateLimit(ethenaBurnKey,    0, 0);
        _assertRateLimit(susdeDepositKey,  0, 0);
        _assertRateLimit(susdeCooldownKey, 0, 0);

        executeAllPayloadsAndBridges();

        // Ethena rate limits after should be properly set
        _assertRateLimit(ethenaMintKey,   ETHENA_MINT_RATE_LIMIT_MAX,    ETHENA_MINT_RATE_LIMIT_SLOPE);
        _assertRateLimit(ethenaBurnKey,   ETHENA_BURN_RATE_LIMIT_MAX,    ETHENA_BURN_RATE_LIMIT_SLOPE);
        _assertRateLimit(susdeDepositKey, ETHENA_DEPOSIT_RATE_LIMIT_MAX, ETHENA_DEPOSIT_RATE_LIMIT_SLOPE);

        _assertUnlimitedRateLimit(susdeCooldownKey);

        IERC20 usdc    = IERC20(Ethereum.USDC);
        IERC20 usde    = IERC20(Ethereum.USDE);
        IERC4626 susde = IERC4626(Ethereum.SUSDE);

        vm.startPrank(Ethereum.ALM_RELAYER);

        // Mint

        assertEq(rateLimits.getCurrentRateLimit(ethenaMintKey),               ETHENA_MINT_RATE_LIMIT_MAX);
        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 0);

        controller.prepareUSDeMint(250_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(ethenaMintKey),              0);
        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 250_000_000e6);

        // Burn

        assertEq(rateLimits.getCurrentRateLimit(ethenaBurnKey),               ETHENA_BURN_RATE_LIMIT_MAX);
        assertEq(usde.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 0);

        controller.prepareUSDeBurn(500_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(ethenaBurnKey),              0);
        assertEq(usde.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 500_000_000e18);

        // sUSDe Deposit

        deal(Ethereum.USDE, Ethereum.ALM_PROXY, 250_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeDepositKey),            250_000_000e18);
        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),                         250_000_000e18);
        assertEq(susde.convertToAssets(susde.balanceOf(Ethereum.ALM_PROXY)), 0);

        controller.depositERC4626(address(susde), 250_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeDepositKey),            0);
        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),                         0);
        assertEq(susde.convertToAssets(susde.balanceOf(Ethereum.ALM_PROXY)), 250_000_000e18 - 1);  // Rounding

        // sUSDe Cooldown

        deal(Ethereum.SUSDE, Ethereum.ALM_PROXY, susde.convertToShares(500_000_000e18) + 1);  // Rounding

        _assertUnlimitedRateLimit(susdeCooldownKey);
        assertEq(susde.convertToAssets(susde.balanceOf(Ethereum.ALM_PROXY)), 500_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(susdeWithdrawKey),           0);

        controller.cooldownAssetsSUSDe(500_000_000e18);

        _assertUnlimitedRateLimit(susdeCooldownKey);
        assertEq(susde.convertToAssets(susde.balanceOf(Ethereum.ALM_PROXY)), 0);

        // Confirm proper recharge rate
        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(ethenaMintKey),   100_000_000e6 / uint256(1 days) * 1 hours);
        assertEq(rateLimits.getCurrentRateLimit(ethenaBurnKey),   200_000_000e18 / uint256(1 days) * 1 hours);
        assertEq(rateLimits.getCurrentRateLimit(susdeDepositKey), 100_000_000e18 / uint256(1 days) * 1 hours);
        _assertUnlimitedRateLimit(susdeCooldownKey);

        // All limits should be reset in 3 days + 1 (rounding)
        skip(71 hours + 1);

        assertEq(rateLimits.getCurrentRateLimit(ethenaMintKey),    ETHENA_MINT_RATE_LIMIT_MAX);
        assertEq(rateLimits.getCurrentRateLimit(ethenaBurnKey),    ETHENA_BURN_RATE_LIMIT_MAX);
        assertEq(rateLimits.getCurrentRateLimit(susdeDepositKey),  ETHENA_DEPOSIT_RATE_LIMIT_MAX);
        _assertUnlimitedRateLimit(susdeCooldownKey);
    }

    function test_AVALANCHE_almSystemDeployment() public onChain(ChainIdUtils.Avalanche()) {
        IALMProxy         almProxy   = IALMProxy(Avalanche.ALM_PROXY);
        IRateLimits       rateLimits = IRateLimits(Avalanche.ALM_RATE_LIMITS);
        ForeignController controller = ForeignController(Avalanche.ALM_CONTROLLER);

        assertEq(almProxy.hasRole(0x0, Avalanche.GROVE_EXECUTOR),   true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Avalanche.GROVE_EXECUTOR), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Avalanche.GROVE_EXECUTOR), true, "incorrect-admin-controller");

        assertEq(almProxy.hasRole(0x0, DEPLOYER),   false, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, DEPLOYER), false, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, DEPLOYER), false, "incorrect-admin-controller");

        assertEq(address(controller.proxy()),      Avalanche.ALM_PROXY,            "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), Avalanche.ALM_RATE_LIMITS,      "incorrect-rateLimits");
        assertEq(address(controller.cctp()),       Avalanche.CCTP_TOKEN_MESSENGER, "incorrect-cctpMessenger");
        assertEq(address(controller.usdc()),       Avalanche.USDC,                 "incorrect-usdc");
        assertEq(address(controller.psm()),        FAKE_PSM3_PLACEHOLDER,          "incorrect-psm");
    }

    function test_AVALANCHE_almSystemInitialization() public onChain(ChainIdUtils.Avalanche()) {
        IALMProxy         almProxy   = IALMProxy(Avalanche.ALM_PROXY);
        IRateLimits       rateLimits = IRateLimits(Avalanche.ALM_RATE_LIMITS);
        ForeignController controller = ForeignController(Avalanche.ALM_CONTROLLER);

        executeAllPayloadsAndBridges();

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), Avalanche.ALM_CONTROLLER), true, "incorrect-controller-almProxy");

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Avalanche.ALM_CONTROLLER), true, "incorrect-controller-rateLimits");

        assertEq(controller.hasRole(controller.FREEZER(), Avalanche.ALM_FREEZER), true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), Avalanche.ALM_RELAYER), true, "incorrect-relayer-controller");

        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),  bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    }

    function test_AVALANCHE_onboardCctpTransfersToEthereum() public onChain(ChainIdUtils.Avalanche()) {
        bytes32 generalCctpKey  = ForeignController(Avalanche.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 ethereumCctpKey = RateLimitHelpers.makeDomainKey(
            ForeignController(Avalanche.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        _assertRateLimit(generalCctpKey,  0, 0);
        _assertRateLimit(ethereumCctpKey, 0, 0);

        assertEq(ForeignController(Avalanche.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM), bytes32(0));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(ethereumCctpKey, AVALANCHE_TO_ETHEREUM_CCTP_RATE_LIMIT_MAX, AVALANCHE_TO_ETHEREUM_CCTP_RATE_LIMIT_SLOPE);

        assertEq(ForeignController(Avalanche.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM), bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    }

    function test_ETHEREUM_AVALANCHE_cctpTransferE2E() public onChain(ChainIdUtils.Ethereum()) {

        executeAllPayloadsAndBridges();

        IERC20 avalancheUsdc = IERC20(Avalanche.USDC);
        IERC20 ethereumUsdc  = IERC20(Ethereum.USDC);

        MainnetController mainnetController   = MainnetController(Ethereum.ALM_CONTROLLER);
        ForeignController avalancheController = ForeignController(Avalanche.ALM_CONTROLLER);

        // --- Step 1: Mint and bridge 10m USDC to Avalanche ---

        uint256 usdcAmount = 50_000_000e6;

        vm.startPrank(Ethereum.ALM_RELAYER);
        mainnetController.mintUSDS(usdcAmount * 1e12);
        mainnetController.swapUSDSToUSDC(usdcAmount);
        mainnetController.transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE);
        vm.stopPrank();

        selectChain(ChainIdUtils.Avalanche());

        assertEq(avalancheUsdc.balanceOf(Avalanche.ALM_PROXY), 0);

        _relayMessageOverBridges();

        assertEq(avalancheUsdc.balanceOf(Avalanche.ALM_PROXY), usdcAmount);

        // --- Step 2: Bridge USDC back to mainnet and burn USDS

        vm.startPrank(Avalanche.ALM_RELAYER);
        avalancheController.transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
        vm.stopPrank();

        assertEq(avalancheUsdc.balanceOf(Avalanche.ALM_PROXY), 0);

        selectChain(ChainIdUtils.Ethereum());

        uint256 usdcPrevBalance = ethereumUsdc.balanceOf(Ethereum.ALM_PROXY);

        _relayMessageOverBridges();

        assertEq(ethereumUsdc.balanceOf(Ethereum.ALM_PROXY), usdcPrevBalance + usdcAmount);

        vm.startPrank(Ethereum.ALM_RELAYER);
        mainnetController.swapUSDCToUSDS(usdcAmount);
        mainnetController.burnUSDS(usdcAmount * 1e12);
        vm.stopPrank();

        assertEq(ethereumUsdc.balanceOf(Ethereum.ALM_PROXY), usdcPrevBalance);
    }

}
