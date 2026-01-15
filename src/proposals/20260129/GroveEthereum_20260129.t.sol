
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { console } from "forge-std/console.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { ChainIdUtils }     from "src/libraries/helpers/ChainId.sol";
import { UniswapV3Helpers } from "src/libraries/helpers/UniswapV3Helpers.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/CommonTestBase.sol";
import { GroveTestBase }              from "src/test-harness/GroveTestBase.sol";

interface IStarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
    function exec() external returns (address);
}

interface IExecutorLike {
    function executeDelegateCall(address target, bytes memory data) external;
}

contract GroveEthereum_20260129_Test is GroveTestBase {

    address internal constant ETHEREUM_20260115_PAYLOAD = 0x90230A17dcA6c0b126521BB55B98f8C6Cf2bA748;
    address internal constant BASE_20260115_PAYLOAD     = 0xAe9EAd94B00d137f01159A7F279c0b78dd04c860;

    bytes32 internal constant ETHEREUM_20260115_CODEHASH = 0x9317fd876201f5a1b08658b47a47c8980b8c8aa7538e059408668b502acfa5fb;

    /******************************************************************************************************************/
    /*** [Mainnet] Re-Onboard Agora AUSD Mint Redeem                                                                ***/
    /******************************************************************************************************************/

    address internal constant AUSD                         = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address internal constant OLD_AGORA_AUSD_MINT_WALLET   = 0xfEa17E5f0e9bF5c86D5d553e2A074199F03B44E8;
    address internal constant NEW_AGORA_AUSD_MINT_WALLET   = 0x748b66a6b3666311F370218Bc2819c0bEe13677e;
    address internal constant NEW_AGORA_AUSD_REDEEM_WALLET = 0xab8306d9FeFBE8183c3C59cA897A2E0Eb5beFE67;


    uint256 internal constant PREV_OLD_AGORA_AUSD_USDC_MINT_MAX   = 50_000_000e6;
    uint256 internal constant PREV_OLD_AGORA_AUSD_USDC_MINT_SLOPE = 50_000_000e6 / uint256(1 days);
    uint256 internal constant OLD_AGORA_AUSD_USDC_MINT_MAX        = 0;
    uint256 internal constant OLD_AGORA_AUSD_USDC_MINT_SLOPE      = 0;

    uint256 internal constant NEW_AGORA_AUSD_USDC_MINT_MAX   = 10_000_000e6;
    uint256 internal constant NEW_AGORA_AUSD_USDC_MINT_SLOPE = 100_000_000e6 / uint256(1 days);

    uint256 internal constant NEW_AGORA_AUSD_USDC_REDEEM_MAX   = 10_000_000e6;
    uint256 internal constant NEW_AGORA_AUSD_USDC_REDEEM_SLOPE = 100_000_000e6 / uint256(1 days);

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Curve AUSD/USDC Swaps & LP                                                               ***/
    /******************************************************************************************************************/

    address internal constant CURVE_AUSD_USDC_POOL = 0xE79C1C7E24755574438A26D5e062Ad2626C04662;

    uint256 internal constant CURVE_AUSD_USDC_TEST_DEPOSIT_TOKEN0 = 10_000_000e6;
    uint256 internal constant CURVE_AUSD_USDC_TEST_SWAP_TOKEN0    = 2_500_000e6;
    uint256 internal constant CURVE_AUSD_USDC_MAX_SLIPPAGE        = 0.999e18;
    uint256 internal constant CURVE_AUSD_USDC_SWAP_MAX            = 5_000_000e18;
    uint256 internal constant CURVE_AUSD_USDC_SWAP_SLOPE          = 100_000_000e18 / uint256(1 days);
    uint256 internal constant CURVE_AUSD_USDC_DEPOSIT_MAX         = 25_000_000e18;
    uint256 internal constant CURVE_AUSD_USDC_DEPOSIT_SLOPE       = 25_000_000e18 / uint256(1 days);
    uint256 internal constant CURVE_AUSD_USDC_WITHDRAW_MAX        = type(uint256).max;
    uint256 internal constant CURVE_AUSD_USDC_WITHDRAW_SLOPE      = 0;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Uniswap v3 AUSD/USDC Swaps & LP                                                          ***/
    /******************************************************************************************************************/

    address internal constant UNISWAP_V3_AUSD_USDC_POOL = 0xbAFeAd7c60Ea473758ED6c6021505E8BBd7e8E5d;

    uint256 internal constant UNISWAP_V3_AUSD_USDC_MAX_SLIPPAGE     = 0.999e18;
    uint32  internal constant UNISWAP_V3_AUSD_USDC_TWAP_SECONDS_AGO = 600;
    uint24  internal constant UNISWAP_V3_AUSD_USDC_MAX_TICK_DELTA   = 200;

    int24 internal constant UNISWAP_V3_AUSD_USDC_LOWER_TICK_BOUND = -10;
    int24 internal constant UNISWAP_V3_AUSD_USDC_UPPER_TICK_BOUND =  10;

    uint256 internal constant UNISWAP_V3_AUSD_USDC_TEST_SWAP_TOKEN0 = 5_000_000e6;

    uint256 internal constant UNISWAP_V3_AUSD_USDC_SWAP_AUSD_MAX   = 5_000_000e6;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_SWAP_AUSD_SLOPE = 100_000_000e6 / uint256(1 days);

    uint256 internal constant UNISWAP_V3_AUSD_USDC_TEST_SWAP_TOKEN1 = 5_000_000e6;

    uint256 internal constant UNISWAP_V3_AUSD_USDC_SWAP_USDC_MAX   = 5_000_000e6;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_SWAP_USDC_SLOPE = 100_000_000e6 / uint256(1 days);

    uint256 internal constant UNISWAP_V3_AUSD_USDC_TEST_DEPOSIT_TOKEN0 = 25_000_000e6;

    uint256 internal constant UNISWAP_V3_AUSD_USDC_DEPOSIT_AUSD_MAX   = 25_000_000e6;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_DEPOSIT_AUSD_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant UNISWAP_V3_AUSD_USDC_TEST_DEPOSIT_TOKEN1 = 25_000_000e6;

    uint256 internal constant UNISWAP_V3_AUSD_USDC_DEPOSIT_USDC_MAX   = 25_000_000e6;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_DEPOSIT_USDC_SLOPE = 25_000_000e6 / uint256(1 days);

    uint256 internal constant UNISWAP_V3_AUSD_USDC_WITHDRAW_AUSD_MAX   = type(uint256).max;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_WITHDRAW_AUSD_SLOPE = 0;

    uint256 internal constant UNISWAP_V3_AUSD_USDC_WITHDRAW_USDC_MAX   = type(uint256).max;
    uint256 internal constant UNISWAP_V3_AUSD_USDC_WITHDRAW_USDC_SLOPE = 0;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Curve PYUSD/USDS Swaps                                                                   ***/
    /******************************************************************************************************************/

    address internal constant CURVE_PYUSD_USDS_POOL = 0xA632D59b9B804a956BfaA9b48Af3A1b74808FC1f;

    uint256 internal constant CURVE_PYUSD_USDS_TEST_SWAP_TOKEN0 = 2_000_000e6;
    uint256 internal constant CURVE_PYUSD_USDS_MAX_SLIPPAGE     = 0.999e18;
    uint256 internal constant CURVE_PYUSD_USDS_SWAP_MAX         = 5_000_000e18;
    uint256 internal constant CURVE_PYUSD_USDS_SWAP_SLOPE       = 100_000_000e18 / uint256(1 days);

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Grove x Steakhouse USDC Morpho Vault                                                     ***/
    /******************************************************************************************************************/

    address internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT = 0xBeefF08dF54897e7544aB01d0e86f013DA354111;

    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_TEST_DEPOSIT         = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_MAX          = 20_000_000e6;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_SLOPE        = 20_000_000e6 / uint256(1 days);
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_SHARE_UNIT           = 1e18;
    uint256 internal constant GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_MAX_ASSETS_PER_SHARE = 2e6;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Steakhouse PYUSD Morpho Vault                                                            ***/
    /******************************************************************************************************************/

    address internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT = 0xd8A6511979D9C5D387c819E9F8ED9F3a5C6c5379;

    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_TEST_DEPOSIT         = 20_000_000e6;
    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_DEPOSIT_MAX          = 20_000_000e6;
    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_DEPOSIT_SLOPE        = 20_000_000e6 / uint256(1 days);
    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_SHARE_UNIT           = 1e18;
    uint256 internal constant STEAKHOUSE_PYUSD_MORPHO_VAULT_MAX_ASSETS_PER_SHARE = 4e6;

    /******************************************************************************************************************/
    /*** [Mainnet] Onboard Relayers for Grove Liquidity Layer                                                       ***/
    /******************************************************************************************************************/

    address internal constant GROVE_CORE_RELAYER_OPERATOR      = 0x4364D17B578b0eD1c42Be9075D774D1d6AeAFe96;
    address internal constant GROVE_SECONDARY_RELAYER_OPERATOR = 0x9187807e07112359C481870feB58f0c117a29179;

    constructor() {
        id = "20260129";
    }

    function setUp() public {
        setupDomains("2026-01-14T13:00:00Z");

        _executePreviousMainnetSpell();
        _executePreviousBaseSpell();

        deployPayloads();
    }

    function _executePreviousMainnetSpell() public onChain(ChainIdUtils.Ethereum()) {
        vm.prank(Ethereum.PAUSE_PROXY);
        IStarGuardLike(Ethereum.GROVE_STAR_GUARD).plot({
            addr_ : ETHEREUM_20260115_PAYLOAD,
            tag_  : ETHEREUM_20260115_CODEHASH
        });

        address returnedPayloadAddress = IStarGuardLike(Ethereum.GROVE_STAR_GUARD).exec();
        require(ETHEREUM_20260115_PAYLOAD == returnedPayloadAddress, "FAILED TO EXECUTE PAYLOAD");
    }

    function _executePreviousBaseSpell() public onChain(ChainIdUtils.Base()) {
        vm.prank(Base.GROVE_EXECUTOR);
        IExecutorLike(Base.GROVE_EXECUTOR).executeDelegateCall(
            BASE_20260115_PAYLOAD,
            abi.encodeWithSignature('execute()')
        );
    }

    function test_ETHEREUM_offboardOldAgoraAusdMint() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 mintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            OLD_AGORA_AUSD_MINT_WALLET
        );

        _assertRateLimit({
            key       : mintKey,
            maxAmount : PREV_OLD_AGORA_AUSD_USDC_MINT_MAX,
            slope     : PREV_OLD_AGORA_AUSD_USDC_MINT_SLOPE
        });

        executeAllPayloadsAndBridges();

        _assertRateLimit({
            key       : mintKey,
            maxAmount : OLD_AGORA_AUSD_USDC_MINT_MAX,  // 0
            slope     : OLD_AGORA_AUSD_USDC_MINT_SLOPE // 0
        });

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        vm.startPrank(ctx.relayer);
        MainnetController(ctx.controller).mintUSDS(1e12);
        MainnetController(ctx.controller).swapUSDSToUSDC(1);
        vm.expectRevert("RateLimits/zero-maxAmount");
        MainnetController(ctx.controller).transferAsset(Ethereum.USDC, OLD_AGORA_AUSD_MINT_WALLET, 1);
        vm.stopPrank();
    }

    function test_ETHEREUM_onboardNewAgoraAusdMint() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : NEW_AGORA_AUSD_MINT_WALLET,
            expectedDepositAmount : NEW_AGORA_AUSD_USDC_MINT_MAX,
            depositMax            : NEW_AGORA_AUSD_USDC_MINT_MAX,
            depositSlope          : NEW_AGORA_AUSD_USDC_MINT_SLOPE
        });
    }

    function test_ETHEREUM_onboardNewAgoraAusdRedeem() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectTokenTransferOnboarding({
            token                 : AUSD,
            destination           : NEW_AGORA_AUSD_REDEEM_WALLET,
            expectedDepositAmount : NEW_AGORA_AUSD_USDC_REDEEM_MAX,
            depositMax            : NEW_AGORA_AUSD_USDC_REDEEM_MAX,
            depositSlope          : NEW_AGORA_AUSD_USDC_REDEEM_SLOPE
        });
    }


    function test_ETHEREUM_onboardCurveAusdUsdcSwapsAndLp() public onChain(ChainIdUtils.Ethereum()) {
        _testCurveOnboarding({
            pool                        : CURVE_AUSD_USDC_POOL,
            expectedDepositAmountToken0 : CURVE_AUSD_USDC_TEST_DEPOSIT_TOKEN0,
            expectedSwapAmountToken0    : CURVE_AUSD_USDC_TEST_SWAP_TOKEN0,
            maxSlippage                 : CURVE_AUSD_USDC_MAX_SLIPPAGE,
            swapMax                     : CURVE_AUSD_USDC_SWAP_MAX,
            swapSlope                   : CURVE_AUSD_USDC_SWAP_SLOPE,
            depositMax                  : CURVE_AUSD_USDC_DEPOSIT_MAX,
            depositSlope                : CURVE_AUSD_USDC_DEPOSIT_SLOPE,
            withdrawMax                 : CURVE_AUSD_USDC_WITHDRAW_MAX,
            withdrawSlope               : CURVE_AUSD_USDC_WITHDRAW_SLOPE
        });
    }

    function test_ETHEREUM_onboardUniswapV3AusdUsdcSwapsAndLp() public onChain(ChainIdUtils.Ethereum()) {
        _testUniswapV3Onboarding({
            context : UniswapV3TestingContext({
                pool   : UNISWAP_V3_AUSD_USDC_POOL,
                token0 : AUSD,
                token1 : Ethereum.USDC
            }),
            params : UniswapV3TestingParams({
                expectedDepositAmountToken0 : UNISWAP_V3_AUSD_USDC_TEST_DEPOSIT_TOKEN0,
                expectedSwapAmountToken0    : UNISWAP_V3_AUSD_USDC_TEST_SWAP_TOKEN0,
                expectedDepositAmountToken1 : UNISWAP_V3_AUSD_USDC_TEST_DEPOSIT_TOKEN1,
                expectedSwapAmountToken1    : UNISWAP_V3_AUSD_USDC_TEST_SWAP_TOKEN1
            }),
            poolParams : UniswapV3Helpers.UniswapV3PoolParams({
                maxSlippage    : UNISWAP_V3_AUSD_USDC_MAX_SLIPPAGE,
                maxTickDelta   : UNISWAP_V3_AUSD_USDC_MAX_TICK_DELTA,
                twapSecondsAgo : UNISWAP_V3_AUSD_USDC_TWAP_SECONDS_AGO,
                lowerTickBound : UNISWAP_V3_AUSD_USDC_LOWER_TICK_BOUND,
                upperTickBound : UNISWAP_V3_AUSD_USDC_UPPER_TICK_BOUND
            }),
            token0Params : UniswapV3Helpers.UniswapV3TokenParams({
                swapMax       : UNISWAP_V3_AUSD_USDC_SWAP_AUSD_MAX,
                swapSlope     : UNISWAP_V3_AUSD_USDC_SWAP_AUSD_SLOPE,
                depositMax    : UNISWAP_V3_AUSD_USDC_DEPOSIT_AUSD_MAX,
                depositSlope  : UNISWAP_V3_AUSD_USDC_DEPOSIT_AUSD_SLOPE,
                withdrawMax   : UNISWAP_V3_AUSD_USDC_WITHDRAW_AUSD_MAX,
                withdrawSlope : UNISWAP_V3_AUSD_USDC_WITHDRAW_AUSD_SLOPE
            }),
            token1Params : UniswapV3Helpers.UniswapV3TokenParams({
                swapMax       : UNISWAP_V3_AUSD_USDC_SWAP_USDC_MAX,
                swapSlope     : UNISWAP_V3_AUSD_USDC_SWAP_USDC_SLOPE,
                depositMax    : UNISWAP_V3_AUSD_USDC_DEPOSIT_USDC_MAX,
                depositSlope  : UNISWAP_V3_AUSD_USDC_DEPOSIT_USDC_SLOPE,
                withdrawMax   : UNISWAP_V3_AUSD_USDC_WITHDRAW_USDC_MAX,
                withdrawSlope : UNISWAP_V3_AUSD_USDC_WITHDRAW_USDC_SLOPE
            })
        });
    }

    function test_ETHEREUM_onboardCurvePyusdUsdsSwaps() public onChain(ChainIdUtils.Ethereum()) {
        _testCurveOnboarding({
            pool                        : CURVE_PYUSD_USDS_POOL,
            expectedDepositAmountToken0 : 0,
            expectedSwapAmountToken0    : CURVE_PYUSD_USDS_TEST_SWAP_TOKEN0,
            maxSlippage                 : CURVE_PYUSD_USDS_MAX_SLIPPAGE,
            swapMax                     : CURVE_PYUSD_USDS_SWAP_MAX,
            swapSlope                   : CURVE_PYUSD_USDS_SWAP_SLOPE,
            depositMax                  : 0,
            depositSlope                : 0,
            withdrawMax                 : 0,
            withdrawSlope               : 0
        });
    }

    function test_ETHEREUM_onboardGroveXSteakhouseUsdcMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT,
            expectedDepositAmount : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_DEPOSIT_SLOPE,
            shareUnit             : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_SHARE_UNIT,
            maxAssetsPerShare     : GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT_MAX_ASSETS_PER_SHARE
        });
    }

    function test_ETHEREUM_onboardSteakhousePyusdMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : STEAKHOUSE_PYUSD_MORPHO_VAULT,
            expectedDepositAmount : STEAKHOUSE_PYUSD_MORPHO_VAULT_TEST_DEPOSIT,
            depositMax            : STEAKHOUSE_PYUSD_MORPHO_VAULT_DEPOSIT_MAX,
            depositSlope          : STEAKHOUSE_PYUSD_MORPHO_VAULT_DEPOSIT_SLOPE,
            shareUnit             : STEAKHOUSE_PYUSD_MORPHO_VAULT_SHARE_UNIT,
            maxAssetsPerShare     : STEAKHOUSE_PYUSD_MORPHO_VAULT_MAX_ASSETS_PER_SHARE
        });
    }

    function test_ETHEREUM_onboardRelayers() public onChain(ChainIdUtils.Ethereum()) {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        MainnetController controller = MainnetController(ctx.controller);

        assertEq(controller.hasRole(controller.RELAYER(), GROVE_CORE_RELAYER_OPERATOR),      false);
        assertEq(controller.hasRole(controller.RELAYER(), GROVE_SECONDARY_RELAYER_OPERATOR), false);

        executeAllPayloadsAndBridges();

        assertEq(controller.hasRole(controller.RELAYER(), GROVE_CORE_RELAYER_OPERATOR),      true);
        assertEq(controller.hasRole(controller.RELAYER(), GROVE_SECONDARY_RELAYER_OPERATOR), true);
    }

    function test_printUniswapKeys() public onChain(ChainIdUtils.Ethereum()) {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
        MainnetController mainnetController = MainnetController(ctx.controller);

        bytes32 uniswapV3_AusdUsdcPool_UsdcSwapKey = RateLimitHelpers.makeAssetDestinationKey(
            mainnetController.LIMIT_UNISWAP_V3_SWAP(),
            Ethereum.USDC,
            UNISWAP_V3_AUSD_USDC_POOL
        );
        console.log("USDC Swap Key");
        console.logBytes32(uniswapV3_AusdUsdcPool_UsdcSwapKey);

        bytes32 uniswapV3_AusdUsdcPool_AusdSwapKey = RateLimitHelpers.makeAssetDestinationKey(
            mainnetController.LIMIT_UNISWAP_V3_SWAP(),
            AUSD,
            UNISWAP_V3_AUSD_USDC_POOL
        );
        console.log("AUSD Swap Key");
        console.logBytes32(uniswapV3_AusdUsdcPool_AusdSwapKey);

        bytes32 uniswapV3_AusdUsdcPool_UsdcAddLiquidityKey = RateLimitHelpers.makeAssetDestinationKey(
            mainnetController.LIMIT_UNISWAP_V3_DEPOSIT(),
            Ethereum.USDC,
            UNISWAP_V3_AUSD_USDC_POOL
        );
        console.log("USDC Add Liquidity Key");
        console.logBytes32(uniswapV3_AusdUsdcPool_UsdcAddLiquidityKey);

        bytes32 uniswapV3_AusdUsdcPool_AusdAddLiquidityKey = RateLimitHelpers.makeAssetDestinationKey(
            mainnetController.LIMIT_UNISWAP_V3_DEPOSIT(),
            AUSD,
            UNISWAP_V3_AUSD_USDC_POOL
        );
        console.log("AUSD Add Liquidity Key");
        console.logBytes32(uniswapV3_AusdUsdcPool_AusdAddLiquidityKey);

        bytes32 uniswapV3_AusdUsdcPool_UsdcRemoveLiquidityKey = RateLimitHelpers.makeAssetDestinationKey(
            mainnetController.LIMIT_UNISWAP_V3_WITHDRAW(),
            Ethereum.USDC,
            UNISWAP_V3_AUSD_USDC_POOL
        );
        console.log("USDC Remove Liquidity Key");
        console.logBytes32(uniswapV3_AusdUsdcPool_UsdcRemoveLiquidityKey);

        bytes32 uniswapV3_AusdUsdcPool_AusdRemoveLiquidityKe     = RateLimitHelpers.makeAssetDestinationKey(
            mainnetController.LIMIT_UNISWAP_V3_WITHDRAW(),
            AUSD,
            UNISWAP_V3_AUSD_USDC_POOL
        );
        console.log("AUSD Remove Liquidity Key");
        console.logBytes32(uniswapV3_AusdUsdcPool_AusdRemoveLiquidityKe);
    }



}
