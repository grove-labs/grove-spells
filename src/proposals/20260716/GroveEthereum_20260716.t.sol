// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { Ethereum }                   from "lib/grove-address-registry/src/Ethereum.sol";
import { Ethereum as SparkContracts } from "lib/spark-address-registry/src/Ethereum.sol";

import { IALMProxy } from "lib/grove-alm-controller/src/interfaces/IALMProxy.sol";

import { IExecutor } from "lib/grove-gov-relay/src/interfaces/IExecutor.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260716_Test is GroveTestBase {

    address internal constant ROBINHOOD_ALM_PROXY       = 0x29626c2d8Ca49A51E4dECEEc5499e52983c42BD5;
    address internal constant ROBINHOOD_ALM_CONTROLLER  = 0x2c10885ddec8d52ecF3Ad2B3833765bf36eD80cf;
    address internal constant ROBINHOOD_ALM_RATE_LIMITS = 0xC13e5ff7993c5df911aE562a7736B0eBA12b2010;
    address internal constant ROBINHOOD_ALM_FREEZER     = 0xB0113804960345fd0a245788b3423319c86940e5;
    // Same Relayer Safes as Ethereum.ALM_RELAYER / Ethereum.GROVE_SECONDARY_RELAYER_OPERATOR,
    // deployed deterministically to the same addresses on Robinhood (forum post, Pre-deployed contracts §5.1).
    address internal constant ROBINHOOD_ALM_RELAYER     = 0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f;
    address internal constant ROBINHOOD_ALM_RELAYER_2   = 0x9187807e07112359C481870feB58f0c117a29179;
    address internal constant ROBINHOOD_GROVE_EXECUTOR  = 0x5ff98717a18833de1A49e11B498866d6Fa1c9296;
    address internal constant ROBINHOOD_GROVE_RECEIVER  = 0xa02eC279eEA9E56F4E14449a07C5ca5FDAAdc51d;
    address internal constant ROBINHOOD_DEPLOYER        = 0x5d63A878F34C6f61559dA0449FabB5fBb5f9F601;

    address internal constant ROBINHOOD_USDG       = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant ROBINHOOD_USDG_VAULT = 0xBEEff039907422219Fb367e525954DDC092854d9;

    // Paxos deposit wallets, must equal the addresses hardcoded in the 20260716 payloads.
    address internal constant ETHEREUM_PAXOS_USDC_DEPOSIT_WALLET   = 0x8C0A9E5939B97979f85d9aDA3d983C6E713Cc2dB;
    address internal constant ROBINHOOD_PAXOS_USDG_DEPOSIT_WALLET  = 0xfC0a7Ed7C5146B26eB38FA92c71F434A7178b06e;

    // syrupUSDC balances pinned to the deterministic mainnet fork block (6 decimals).
    uint256 internal constant GROVE_SYRUP_USDC_BALANCE = 85_943_747.637271e6;
    uint256 internal constant SPARK_SYRUP_USDC_BALANCE = 89_829_171.020922e6;

    constructor() {
        id = "20260716";
    }

    function setUp() public {
        setupDomains("2026-07-06T20:11:00Z");
        deployPayloads();
    }

    function test_ETHEREUM_onboardPaxosUsdcBridgeRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : ETHEREUM_PAXOS_USDC_DEPOSIT_WALLET,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : 50_000_000e6,
            depositSlope          : 50_000_000e6 / uint256(1 days)
        });
    }

    function test_ETHEREUM_transferSyrupUsdcToSpark() public onChain(ChainIdUtils.Ethereum()) {
        IERC20    syrupUsdc = IERC20(Ethereum.MAPLE_SYRUP_USDC);
        IALMProxy almProxy  = IALMProxy(Ethereum.ALM_PROXY);

        bytes32 controllerRole = almProxy.CONTROLLER();

        assertEq(syrupUsdc.balanceOf(Ethereum.ALM_PROXY),       GROVE_SYRUP_USDC_BALANCE);
        assertEq(syrupUsdc.balanceOf(SparkContracts.ALM_PROXY), SPARK_SYRUP_USDC_BALANCE);

        assertEq(almProxy.hasRole(controllerRole, Ethereum.GROVE_PROXY), false);

        executeAllPayloadsAndBridges();

        assertEq(syrupUsdc.balanceOf(Ethereum.ALM_PROXY),       0);
        assertEq(syrupUsdc.balanceOf(SparkContracts.ALM_PROXY), SPARK_SYRUP_USDC_BALANCE + GROVE_SYRUP_USDC_BALANCE);

        assertEq(almProxy.hasRole(controllerRole, Ethereum.GROVE_PROXY), false);
    }

    function test_ETHEREUM_groveProxyCanFundRobinhoodBridge() public onChain(ChainIdUtils.Ethereum()) {
        // The Robinhood relay leg (GrovePayloadEthereum.execute) escrows
        // gasLimit * maxFeePerGas = 1_000_000 * 50e9 = 0.05 ETH per retryable ticket, paid from
        // GROVE_PROXY during delegatecall execution. 0.001 ether of headroom covers the inbox
        // submission fee, (1400 + 6 * dataLength) * baseFee = 4880 * baseFee for the 580-byte
        // queue message, up to a ~200 gwei L1 basefee.
        assertGe(
            Ethereum.GROVE_PROXY.balance,
            1_000_000 * 50e9 + 0.001 ether,
            "grove-proxy-cannot-fund-robinhood-bridge"
        );
    }

    function test_ROBINHOOD_almSystemDeployment() public onChain(ChainIdUtils.Robinhood()) {
        address[] memory relayers = new address[](2);
        relayers[0] = ROBINHOOD_ALM_RELAYER;
        relayers[1] = ROBINHOOD_ALM_RELAYER_2;

        _verifyForeignAlmSystemDeployment(
            AlmSystemContracts({
                admin      : ROBINHOOD_GROVE_EXECUTOR,
                proxy      : ROBINHOOD_ALM_PROXY,
                rateLimits : ROBINHOOD_ALM_RATE_LIMITS,
                controller : ROBINHOOD_ALM_CONTROLLER
            }),
            AlmSystemActors({
                deployer : ROBINHOOD_DEPLOYER,
                freezer  : ROBINHOOD_ALM_FREEZER,
                relayers : relayers
            }),
            ForeignAlmSystemDependencies({
                psm                      : address(0),
                usdc                     : address(0),
                cctp                     : address(0),
                pendleRouter             : address(0),
                uniswapV3Router          : address(0),
                uniswapV3PositionManager : address(0)
            })
        );

        _verifyArbitrumReceiverDeployment({
            _executor : ROBINHOOD_GROVE_EXECUTOR,
            _receiver : ROBINHOOD_GROVE_RECEIVER
        });

        _verifyForeignDomainExecutorDeployment({
            _executor      : ROBINHOOD_GROVE_EXECUTOR,
            _receiver      : ROBINHOOD_GROVE_RECEIVER,
            _deployer      : ROBINHOOD_DEPLOYER,
            _expectedDelay : 1 days
        });
    }

    function test_ROBINHOOD_almSystemInitialization() public onChain(ChainIdUtils.Robinhood()) {
        address[] memory relayers = new address[](2);
        relayers[0] = ROBINHOOD_ALM_RELAYER;
        relayers[1] = ROBINHOOD_ALM_RELAYER_2;

        _testControllerInitialization(
            ROBINHOOD_ALM_CONTROLLER,
            ControllerConfigParams({
                freezer  : ROBINHOOD_ALM_FREEZER,
                relayers : relayers
            })
        );
    }

    function test_ROBINHOOD_bridgedDeliveryAndExecution() public onChain(ChainIdUtils.Robinhood()) {
        IExecutor executor = IExecutor(ROBINHOOD_GROVE_EXECUTOR);
        address   payload  = chainData[ChainIdUtils.Robinhood()].payload;

        assertTrue(payload != address(0), "robinhood-payload-not-deployed");

        address[] memory targets           = new address[](1);
        uint256[] memory values            = new uint256[](1);
        string[]  memory signatures        = new string[](1);
        bytes[]   memory calldatas         = new bytes[](1);
        bool[]    memory withDelegatecalls = new bool[](1);

        targets[0]           = payload;
        values[0]            = 0;
        signatures[0]        = "execute()";
        calldatas[0]         = "";
        withDelegatecalls[0] = true;

        bytes memory message = abi.encodeCall(IExecutor.queue, (
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls
        ));

        // The Delayed Inbox delivers L1-contract-originated messages from the aliased sender;
        // ArbitrumReceiver._getL1MessageSender subtracts the offset to recover GROVE_PROXY.
        address aliasedGroveProxy;
        unchecked {
            aliasedGroveProxy = address(uint160(Ethereum.GROVE_PROXY) + uint160(0x1111000000000000000000000000000000001111));
        }

        uint256 countBefore = executor.actionsSetCount();

        vm.prank(aliasedGroveProxy);
        (bool ok, ) = ROBINHOOD_GROVE_RECEIVER.call{gas: 1_000_000}(message);

        assertTrue(ok,                                        "robinhood-delivery-failed-within-gas-limit");
        assertEq(executor.actionsSetCount(), countBefore + 1, "robinhood-actions-set-not-queued");

        uint256 actionsSetId = executor.actionsSetCount() - 1;

        vm.warp(executor.getActionsSetById(actionsSetId).executionTime);
        executor.execute(actionsSetId);

        assertTrue(executor.getActionsSetById(actionsSetId).executed, "robinhood-actions-set-not-executed");

        IALMProxy almProxy = IALMProxy(ROBINHOOD_ALM_PROXY);
        assertTrue(
            almProxy.hasRole(almProxy.CONTROLLER(), ROBINHOOD_ALM_CONTROLLER),
            "robinhood-payload-effects-missing"
        );
    }

    function test_ROBINHOOD_onboardPaxosUsdgBridgeRateLimit() public onChain(ChainIdUtils.Robinhood()) {
        _testDirectTokenTransferOnboarding({
            token                 : ROBINHOOD_USDG,
            destination           : ROBINHOOD_PAXOS_USDG_DEPOSIT_WALLET,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : 50_000_000e6,
            depositSlope          : 50_000_000e6 / uint256(1 days)
        });
    }

    function test_ROBINHOOD_onboardGroveXSteakhouseUsdgVault() public onChain(ChainIdUtils.Robinhood()) {
        // The vault's underlying and the token/share decimals must match the spell's units
        // (50_000_000e6 deposit limits, 1e18 shareUnit, 1.15e6 maxAssetsPerShare).
        assertEq(IERC4626(ROBINHOOD_USDG_VAULT).asset(),  ROBINHOOD_USDG, "vault-asset-is-not-usdg");
        assertEq(IERC20(ROBINHOOD_USDG).decimals(),       6,              "usdg-decimals-not-6");
        assertEq(IERC20(ROBINHOOD_USDG_VAULT).decimals(), 18,             "vault-share-decimals-not-18");

        _testERC4626Onboarding({
            vault                 : ROBINHOOD_USDG_VAULT,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : 50_000_000e6,
            depositSlope          : 50_000_000e6 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 1.15e6
        });
    }

}
