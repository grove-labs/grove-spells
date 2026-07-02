// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260716_Test is GroveTestBase {

    address internal constant ROBINHOOD_ALM_PROXY       = 0x29626c2d8Ca49A51E4dECEEc5499e52983c42BD5;
    address internal constant ROBINHOOD_ALM_CONTROLLER  = 0x2c10885ddec8d52ecF3Ad2B3833765bf36eD80cf;
    address internal constant ROBINHOOD_ALM_RATE_LIMITS = 0xC13e5ff7993c5df911aE562a7736B0eBA12b2010;
    address internal constant ROBINHOOD_ALM_FREEZER     = 0xB0113804960345fd0a245788b3423319c86940e5;
    // TODO Confirm that correct relayers are onboarded and relayers are correctly deployed and configured
    address internal constant ROBINHOOD_ALM_RELAYER     = 0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f;
    address internal constant ROBINHOOD_ALM_RELAYER_2   = 0x9187807e07112359C481870feB58f0c117a29179;
    address internal constant ROBINHOOD_GROVE_EXECUTOR  = 0x5ff98717a18833de1A49e11B498866d6Fa1c9296;
    address internal constant ROBINHOOD_GROVE_RECEIVER  = 0xa02eC279eEA9E56F4E14449a07C5ca5FDAAdc51d;
    address internal constant ROBINHOOD_DEPLOYER        = 0x5d63A878F34C6f61559dA0449FabB5fBb5f9F601;

    address internal constant ROBINHOOD_USDG       = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant ROBINHOOD_USDG_VAULT = 0xBEEff039907422219Fb367e525954DDC092854d9;

    // Paxos deposit wallets; must match the payloads.
    address internal constant ETHEREUM_PAXOS_USDC_DEPOSIT_WALLET   = 0x8C0A9E5939B97979f85d9aDA3d983C6E713Cc2dB;
    address internal constant ROBINHOOD_PAXOS_USDG_DEPOSIT_WALLET  = 0xfC0a7Ed7C5146B26eB38FA92c71F434A7178b06e;

    constructor() {
        id = "20260716";
    }

    function setUp() public {
        setupDomains("2026-06-29T20:11:00Z");
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
        // groveUSDG is a Morpho Vault V2 with unconfigured deposit caps: absoluteCap/relativeCap are 0 at
        // every block, so maxDeposit is 0 for all receivers and the real depositERC4626 in
        // _testERC4626Onboarding reverts. Raising the caps requires a curator submit + 7-day timelock, so
        // this cannot run on the fork yet. Re-enable once the vault caps are configured on Robinhood.
        vm.skip(true);

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
