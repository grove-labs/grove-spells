
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { CastingHelpers }        from "src/libraries/helpers/CastingHelpers.sol";
import { ChainIdUtils, ChainId } from "src/libraries/helpers/ChainId.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/CommonTestBase.sol";
import { GroveTestBase }              from "src/test-harness/GroveTestBase.sol";

interface AutoLineLike {
    function exec(bytes32) external;
}

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
}

contract GroveEthereum_20260115_Test is GroveTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    address internal constant MAINNET_NEW_CONTROLLER              = 0xfd9dEA9a8D5B955649579Af482DB7198A392A9F5;
    address internal constant MAINNET_AGORA_AUSD_USDC_MINT_WALLET = 0xfEa17E5f0e9bF5c86D5d553e2A074199F03B44E8;

    uint256 internal constant MAINNET_CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant MAINNET_CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant MAINNET_OFFBOARDED_AGORA_AUSD_USDC_MINT_MAX   = 50_000_000e6;
    uint256 internal constant MAINNET_OFFBOARDED_AGORA_AUSD_USDC_MINT_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT  = 20_000_000e6;
    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX   = 20_000_000e6;
    uint256 internal constant BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint256 internal constant BASE_CCTP_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant BASE_CCTP_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    constructor() {
        id = "20260115";
    }

    function setUp() public {
        setupDomains("2025-12-26T20:30:00Z");

        deployPayloads();

        // Prepare testing setup for the controller upgrade
        chainData[ChainIdUtils.Ethereum()].newController  = MAINNET_NEW_CONTROLLER;

        // Warp to ensure all rate limits and autoline cooldown are reset
        vm.warp(block.timestamp + 1 days);
        AutoLineLike(Ethereum.AUTO_LINE).exec(GROVE_ALLOCATOR_ILK);
    }

    function test_ETHEREUM_upgradeController() public onChain(ChainIdUtils.Ethereum()) {
        address[] memory relayers = new address[](1);
        relayers[0] = Ethereum.ALM_RELAYER;

        _testControllerUpgrade(
            Ethereum.ALM_CONTROLLER,
            MAINNET_NEW_CONTROLLER,
            ControllerConfigParams({
                freezer  : Ethereum.ALM_FREEZER,
                relayers : relayers
            })
        );
    }

    function test_ETHEREUM_upgradedControllerState() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        MainnetController controller = MainnetController(MAINNET_NEW_CONTROLLER);

        // 1e18 shares, 1.3e18 max expected assets
        assertEq(controller.maxExchangeRates(Ethereum.SUSDE), 1.3e36);

        // 1e18 shares, 1.15e6 max expected assets
        assertEq(controller.maxExchangeRates(Ethereum.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT), 1.15e24);

        assertEq(controller.maxSlippages(Ethereum.CURVE_RLUSD_USDC),   0.9990e18);
        assertEq(controller.maxSlippages(Ethereum.AAVE_CORE_RLUSD),    0.9990e18);
        assertEq(controller.maxSlippages(Ethereum.AAVE_CORE_USDC),     0.9990e18);
        assertEq(controller.maxSlippages(Ethereum.AAVE_HORIZON_RLUSD), 0.9990e18);
        assertEq(controller.maxSlippages(Ethereum.AAVE_HORIZON_USDC),  0.9990e18);
    }

    function test_ETHEREUM_onboardCctpTransfersToBase() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 generalCctpKey  = MainnetController(MAINNET_NEW_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 baseCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(MAINNET_NEW_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE
        );

        _assertUnlimitedRateLimit(generalCctpKey); // Set in the GroveEthereum_20250807 proposal
        _assertRateLimit(baseCctpKey, 0, 0);

        assertEq(MainnetController(MAINNET_NEW_CONTROLLER).mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE), bytes32(0));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(baseCctpKey, MAINNET_CCTP_RATE_LIMIT_MAX, MAINNET_CCTP_RATE_LIMIT_SLOPE);

        assertEq(
            MainnetController(MAINNET_NEW_CONTROLLER).mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE),
            CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY)
        );
    }

    function test_ETHEREUM_offboardAgoraAusd() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 mintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(MAINNET_NEW_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            MAINNET_AGORA_AUSD_USDC_MINT_WALLET
        );

        _assertRateLimit(mintKey, MAINNET_OFFBOARDED_AGORA_AUSD_USDC_MINT_MAX, MAINNET_OFFBOARDED_AGORA_AUSD_USDC_MINT_SLOPE);

        executeAllPayloadsAndBridges();

        _assertZeroRateLimit(mintKey);

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        vm.startPrank(ctx.relayer);
        MainnetController(ctx.controller).mintUSDS(1e12);
        MainnetController(ctx.controller).swapUSDSToUSDC(1);
        vm.expectRevert("RateLimits/zero-maxAmount");
        MainnetController(ctx.controller).transferAsset(Ethereum.USDC, MAINNET_AGORA_AUSD_USDC_MINT_WALLET, 1);
        vm.stopPrank();

    }

    function test_BASE_governanceDeployment() public onChain(ChainIdUtils.Base()) {
        _verifyForeignDomainExecutorDeployment({
            _executor : Base.GROVE_EXECUTOR,
            _receiver : Base.GROVE_RECEIVER,
            _deployer : DEPLOYER
        });
        _verifyOptimismReceiverDeployment({
            _executor : Base.GROVE_EXECUTOR,
            _receiver : Base.GROVE_RECEIVER
        });
    }

    function test_BASE_almSystemDeployment() public onChain(ChainIdUtils.Base()) {
        address[] memory relayers = new address[](2);
        relayers[0] = Base.ALM_RELAYER;
        relayers[1] = Base.ALM_RELAYER_2;

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
                relayers : relayers
            }),
            ForeignAlmSystemDependencies({
                cctp : Base.CCTP_TOKEN_MESSENGER_V2,
                psm  : Base.PSM3,
                usdc : Base.USDC
            })
        );
    }

    function test_BASE_almSystemInitialization() public onChain(ChainIdUtils.Base()) {
        address[] memory relayers = new address[](2);
        relayers[0] = Base.ALM_RELAYER;
        relayers[1] = Base.ALM_RELAYER_2;

        _testControllerInitialization(Base.ALM_CONTROLLER, ControllerConfigParams({
            freezer  : Base.ALM_FREEZER,
            relayers : relayers
        }));
    }

    function test_BASE_onboardGroveXSteakhouseUsdcMorphoVault() public onChain(ChainIdUtils.Base()) {
        _testERC4626Onboarding({
            vault                 : Base.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            expectedDepositAmount : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : BASE_GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT_DEPOSIT_SLOPE
        });
    }

    function test_BASE_onboardCctpTransfersToEthereum() public onChain(ChainIdUtils.Base()) {
        bytes32 generalCctpKey  = ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 ethereumCctpKey = RateLimitHelpers.makeDomainKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        _assertRateLimit(generalCctpKey,  0, 0);
        _assertRateLimit(ethereumCctpKey, 0, 0);

        assertEq(ForeignController(Base.ALM_CONTROLLER).mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM), bytes32(0));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(ethereumCctpKey, BASE_CCTP_RATE_LIMIT_MAX, BASE_CCTP_RATE_LIMIT_SLOPE);

        assertEq(
            ForeignController(Base.ALM_CONTROLLER).mintRecipients(CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
        );
    }

    function test_ETHEREUM_BASE_cctpTransferE2E() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        ChainId[] memory chains = new ChainId[](1);
        chains[0] = ChainIdUtils.Base();

        IERC20Like baseUsdc     = IERC20Like(Base.USDC);
        IERC20Like ethereumUsdc = IERC20Like(Ethereum.USDC);

        MainnetController mainnetController = MainnetController(MAINNET_NEW_CONTROLLER);
        ForeignController baseController    = ForeignController(Base.ALM_CONTROLLER);

        // --- Step 1: Mint and bridge 10m USDC to Base ---

        uint256 usdcAmount = 10_000_000e6;

        vm.startPrank(Ethereum.ALM_RELAYER);
        mainnetController.mintUSDS(usdcAmount * 1e12);
        mainnetController.swapUSDSToUSDC(usdcAmount);
        mainnetController.transferUSDCToCCTP(usdcAmount, CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        selectChain(ChainIdUtils.Base());

        assertEq(baseUsdc.balanceOf(Base.ALM_PROXY), 0, "Base ALM proxy should have no USDC before message relay");

        _relayMessageOverBridges(chains);

        assertEq(baseUsdc.balanceOf(Base.ALM_PROXY), usdcAmount, "Base ALM proxy should have USDC after message relay");

        // --- Step 2: Bridge USDC back to mainnet and burn USDS

        vm.startPrank(Base.ALM_RELAYER);
        baseController.transferUSDCToCCTP(usdcAmount, CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
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
