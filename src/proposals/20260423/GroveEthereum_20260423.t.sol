// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { LZForwarder }   from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { ChainIdUtils, ChainId }      from "src/libraries/helpers/ChainId.sol";
import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260423_Test is GroveTestBase {

    address internal constant PAYLOAD_ETHEREUM  = 0x76Ba24676e1055D3E6b160086f0bc9BaffF76929;
    address internal constant PAYLOAD_AVALANCHE = 0x1204f2C342706cE6B75997c89619D130Ee9dDa2c;

    address internal constant MAINNET_CENTRIFUGE_JTRSY_USDS = 0x381f4F3B43C30B78C1f7777553236e57bB8AE9ff;

    address internal constant MAINNET_USDS_OFT = 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8;

    address internal constant AVALANCHE_USDS_OFT = 0x4fec40719fD9a8AE3F8E20531669DEC5962D2619;
    address internal constant AVALANCHE_USDS     = 0x86Ff09db814ac346a7C6FE2Cd648F27706D1D470;

    address internal constant NEW_AVALANCHE_CONTROLLER = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;
    address internal constant AVALANCHE_DEPLOYER       = 0xC60b3F7C23Fc5ED78798BB120635bBB7A7D84310;
    address internal constant AVALANCHE_ALM_RELAYER_2  = 0x9187807e07112359C481870feB58f0c117a29179;

    address internal constant AVALANCHE_CURVE_USDS_USDC_POOL = 0xA9d7d3D7e68a0cae89FB33c736199172f405C8D3;

    constructor() {
        id = "20260423";
    }

    function setUp() public {
        setupDomains("2026-04-17T17:18:00Z");

        chainData[ChainIdUtils.Avalanche()].newController = NEW_AVALANCHE_CONTROLLER;

        chainData[ChainIdUtils.Ethereum()].payload  = PAYLOAD_ETHEREUM;
        chainData[ChainIdUtils.Avalanche()].payload = PAYLOAD_AVALANCHE;
    }

    function test_ETHEREUM_increaseUsdsMintRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 mintKey = GroveLiquidityLayerHelpers.LIMIT_USDS_MINT;

        _assertRateLimit(mintKey, 100_000_000e18, 50_000_000e18 / uint256(1 days));

        executeAllPayloadsAndBridges();

        _assertRateLimit(mintKey, 500_000_000e18, 500_000_000e18 / uint256(1 days));
    }

    function test_ETHEREUM_onboardCentrifugeJtrsyUsds() public onChain(ChainIdUtils.Ethereum()) {
        _testCentrifugeV3Onboarding({
            centrifugeVault : MAINNET_CENTRIFUGE_JTRSY_USDS,
            depositMax      : 500_000_000e18,
            depositSlope    : 500_000_000e18 / uint256(1 days)
        });
    }

    function test_ETHEREUM_onboardUsdsSkyLinkTransfersToAvalanche() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        bytes32 lzTransferKey = keccak256(abi.encode(
            controller.LIMIT_LAYERZERO_TRANSFER(),
            MAINNET_USDS_OFT,
            LZForwarder.ENDPOINT_ID_AVALANCHE
        ));

        assertEq(controller.layerZeroRecipients(LZForwarder.ENDPOINT_ID_AVALANCHE), bytes32(0));
        _assertZeroRateLimit(lzTransferKey);

        executeAllPayloadsAndBridges();

        assertEq(
            controller.layerZeroRecipients(LZForwarder.ENDPOINT_ID_AVALANCHE),
            CastingHelpers.addressToLayerZeroRecipient(Avalanche.ALM_PROXY)
        );
        _assertRateLimit(lzTransferKey, 50_000_000e18, 50_000_000e18 / uint256(1 days));
    }

    function test_AVALANCHE_upgradeController() public onChain(ChainIdUtils.Avalanche()) {
        address[] memory relayers = new address[](2);
        relayers[0] = Avalanche.ALM_RELAYER;
        relayers[1] = AVALANCHE_ALM_RELAYER_2;

        _verifyForeignControllerDeployment(
            AlmSystemContracts({
                admin      : Avalanche.GROVE_EXECUTOR,
                proxy      : Avalanche.ALM_PROXY,
                rateLimits : Avalanche.ALM_RATE_LIMITS,
                controller : NEW_AVALANCHE_CONTROLLER
            }),
            AlmSystemActors({
                deployer : AVALANCHE_DEPLOYER,
                freezer  : Avalanche.ALM_FREEZER,
                relayers : relayers
            }),
            ForeignAlmSystemDependencies({
                psm                      : address(ForeignController(Avalanche.ALM_CONTROLLER).psm()),
                usdc                     : Avalanche.USDC,
                cctp                     : Avalanche.CCTP_TOKEN_MESSENGER_V2,
                pendleRouter             : address(0xDeaDBeef),
                uniswapV3Router          : Avalanche.UNISWAP_V3_SWAP_ROUTER_02,
                uniswapV3PositionManager : Avalanche.UNISWAP_V3_POSITION_MANAGER
            })
        );

        _testControllerUpgrade({
            oldController : Avalanche.ALM_CONTROLLER,
            newController : NEW_AVALANCHE_CONTROLLER,
            configParams  : ControllerConfigParams({
                freezer  : Avalanche.ALM_FREEZER,
                relayers : relayers
            })
        });
    }

    function test_AVALANCHE_setMintRecipients() public onChain(ChainIdUtils.Avalanche()) {
        ForeignController newController = ForeignController(NEW_AVALANCHE_CONTROLLER);

        assertEq(newController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM), bytes32(0));
        assertEq(newController.layerZeroRecipients(LZForwarder.ENDPOINT_ID_ETHEREUM), bytes32(0));
        assertEq(newController.centrifugeRecipients(1), bytes32(0));

        executeAllPayloadsAndBridges();

        assertEq(
            newController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            bytes32(uint256(uint160(Ethereum.ALM_PROXY)))
        );
        assertEq(
            newController.layerZeroRecipients(LZForwarder.ENDPOINT_ID_ETHEREUM),
            CastingHelpers.addressToLayerZeroRecipient(Ethereum.ALM_PROXY)
        );
        assertEq(
            newController.centrifugeRecipients(1),
            CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY)
        );
    }

    function test_AVALANCHE_onboardUsdsSkyLinkTransfersToEthereum() public onChain(ChainIdUtils.Avalanche()) {
        ForeignController controller = ForeignController(NEW_AVALANCHE_CONTROLLER);

        bytes32 lzTransferKey = keccak256(abi.encode(
            controller.LIMIT_LAYERZERO_TRANSFER(),
            AVALANCHE_USDS_OFT,
            LZForwarder.ENDPOINT_ID_ETHEREUM
        ));

        _assertZeroRateLimit(lzTransferKey);

        executeAllPayloadsAndBridges();

        _assertRateLimit(lzTransferKey, 20_000_000e18, 20_000_000e18 / uint256(1 days));
    }

    function test_AVALANCHE_increaseCctpUsdcTransferToEthereumRateLimit() public onChain(ChainIdUtils.Avalanche()) {
        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            ForeignController(NEW_AVALANCHE_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(domainKey);
    }

    function test_AVALANCHE_onboardCurveUsdsUsdcPool() public onChain(ChainIdUtils.Avalanche()) {
        _testCurveOnboarding({
            pool                        : AVALANCHE_CURVE_USDS_USDC_POOL,
            expectedDepositAmountToken0 : 10_000_000e6,
            expectedSwapAmountToken0    : 2_500_000e6,
            maxSlippage                 : 0.999e18,
            swapMax                     : 5_000_000e18,
            swapSlope                   : 100_000_000e18 / uint256(1 days),
            depositMax                  : 50_000_000e18,
            depositSlope                : 50_000_000e18 / uint256(1 days),
            withdrawMax                 : type(uint256).max,
            withdrawSlope               : 0
        });
    }

    function test_ETHEREUM_AVALANCHE_layerZeroTransferE2E() public onChain(ChainIdUtils.Ethereum()) {

        executeAllPayloadsAndBridges();

        IERC20 ethereumUsds  = IERC20(Ethereum.USDS);
        IERC20 avalancheUsds = IERC20(AVALANCHE_USDS);

        MainnetController mainnetController   = MainnetController(Ethereum.ALM_CONTROLLER);
        ForeignController avalancheController = ForeignController(NEW_AVALANCHE_CONTROLLER);

        ChainId[] memory avalancheOnly = new ChainId[](1);
        avalancheOnly[0] = ChainIdUtils.Avalanche();

        // --- Step 1: Mint USDS and bridge to Avalanche via LayerZero ---

        uint256 usdsAmount = 2_500_000e18;

        deal(Ethereum.ALM_RELAYER, 0.001 ether);

        vm.startPrank(Ethereum.ALM_RELAYER);
        mainnetController.mintUSDS(usdsAmount);
        mainnetController.transferTokenLayerZero{value: 0.001 ether}(
            MAINNET_USDS_OFT,
            usdsAmount,
            LZForwarder.ENDPOINT_ID_AVALANCHE
        );
        vm.stopPrank();

        selectChain(ChainIdUtils.Avalanche());

        assertEq(avalancheUsds.balanceOf(Avalanche.ALM_PROXY), 0);

        _relayMessageOverBridges(avalancheOnly);

        assertEq(avalancheUsds.balanceOf(Avalanche.ALM_PROXY), usdsAmount);

        // --- Step 2: Bridge USDS back to Ethereum via LayerZero ---

        deal(Avalanche.ALM_RELAYER, 1 ether);

        vm.prank(Avalanche.ALM_RELAYER);
        avalancheController.transferTokenLayerZero{value: 1 ether}(
            AVALANCHE_USDS_OFT,
            usdsAmount,
            LZForwarder.ENDPOINT_ID_ETHEREUM
        );

        assertEq(avalancheUsds.balanceOf(Avalanche.ALM_PROXY), 0);

        selectChain(ChainIdUtils.Ethereum());

        uint256 usdsPrevBalance = ethereumUsds.balanceOf(Ethereum.ALM_PROXY);

        _relayMessageOverBridges(avalancheOnly);

        assertEq(ethereumUsds.balanceOf(Ethereum.ALM_PROXY), usdsPrevBalance + usdsAmount);

        vm.prank(Ethereum.ALM_RELAYER);
        mainnetController.burnUSDS(usdsAmount);
    }

}
