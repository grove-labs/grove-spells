// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { LZForwarder }   from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { IExecutor } from "lib/grove-gov-relay/src/interfaces/IExecutor.sol";

import { ChainIdUtils }               from "src/libraries/helpers/ChainId.sol";
import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260423_Test is GroveTestBase {

    address internal constant CENTRIFUGE_JTRSY_USDS = 0x381f4F3B43C30B78C1f7777553236e57bB8AE9ff;

    address internal constant USDS_OFT_ETHEREUM  = 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8;
    address internal constant USDS_OFT_AVALANCHE = 0x4fec40719fD9a8AE3F8E20531669DEC5962D2619;

    address internal constant NEW_AVALANCHE_CONTROLLER = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;

    address internal constant DEPLOYER = 0xC60b3F7C23Fc5ED78798BB120635bBB7A7D84310;

    address internal constant ALM_RELAYER_2 = 0x9187807e07112359C481870feB58f0c117a29179;

    address internal constant CURVE_USDS_USDC_POOL = 0xA9d7d3D7e68a0cae89FB33c736199172f405C8D3;

    constructor() {
        id = "20260423";
    }

    function setUp() public {
        setupDomains("2026-04-09T12:00:00Z");

        chainData[ChainIdUtils.Avalanche()].newController = NEW_AVALANCHE_CONTROLLER;

        deployPayloads();
    }

    function test_ETHEREUM_onboardCentrifugeJtrsyUsds() public onChain(ChainIdUtils.Ethereum()) {
        _testCentrifugeV3Onboarding({
            centrifugeVault : CENTRIFUGE_JTRSY_USDS,
            depositMax      : 500_000_000e18,
            depositSlope    : 500_000_000e18 / uint256(1 days)
        });
    }

    function test_ETHEREUM_increaseUsdsMintRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 mintKey = GroveLiquidityLayerHelpers.LIMIT_USDS_MINT;

        _assertRateLimit(mintKey, 100_000_000e18, 50_000_000e18 / uint256(1 days));

        executeAllPayloadsAndBridges();

        _assertRateLimit(mintKey, 500_000_000e18, 500_000_000e18 / uint256(1 days));
    }

    function test_ETHEREUM_onboardUsdsSkyLinkTransfersToAvalanche() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        bytes32 lzTransferKey = keccak256(abi.encode(
            controller.LIMIT_LAYERZERO_TRANSFER(),
            USDS_OFT_ETHEREUM,
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
        relayers[1] = ALM_RELAYER_2;

        _verifyForeignControllerDeployment(
            AlmSystemContracts({
                admin      : Avalanche.GROVE_EXECUTOR,
                proxy      : Avalanche.ALM_PROXY,
                rateLimits : Avalanche.ALM_RATE_LIMITS,
                controller : NEW_AVALANCHE_CONTROLLER
            }),
            AlmSystemActors({
                deployer : DEPLOYER,
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
            USDS_OFT_AVALANCHE,
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
            pool                        : CURVE_USDS_USDC_POOL,
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
        vm.skip(true);
        // TODO: Implement end-to-end LayerZero USDS transfer test (modeled after test_ETHEREUM_AVALANCHE_cctpTransferE2E in archive/20250807)
        //
        // Step 1: Execute all payloads and bridges
        //   - executeAllPayloadsAndBridges()
        //
        // Step 2: Ethereum → Avalanche transfer
        //   - Mint USDS on Ethereum via mainnetController.mintUSDS(amount)
        //   - Call mainnetController.transferTokenLayerZero(USDS_OFT_ETHEREUM, amount, ENDPOINT_ID_AVALANCHE) as relayer
        //   - Assert USDS balance decreased on Ethereum ALM_PROXY
        //   - selectChain(ChainIdUtils.Avalanche())
        //   - Assert USDS balance on Avalanche ALM_PROXY is 0 before relay
        //   - _relayMessageOverBridges()
        //   - Assert USDS balance on Avalanche ALM_PROXY increased by the bridged amount
        //
        // Step 3: Avalanche → Ethereum transfer
        //   - Call foreignController.transferTokenLayerZero(USDS_OFT_AVALANCHE, amount, ENDPOINT_ID_ETHEREUM) as relayer
        //   - Assert USDS balance on Avalanche ALM_PROXY is 0
        //   - selectChain(ChainIdUtils.Ethereum())
        //   - Record USDS balance on Ethereum ALM_PROXY before relay
        //   - _relayMessageOverBridges()
        //   - Assert USDS balance on Ethereum ALM_PROXY increased by the bridged amount
        //   - Burn USDS via mainnetController.burnUSDS(amount) to clean up
        //   - Assert final balances are consistent
    }

}
