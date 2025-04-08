// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/BloomTestBase.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/bloom-address-registry/src/Ethereum.sol";

import { RateLimitHelpers } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

import { MainnetController } from "bloom-alm-controller/src/MainnetController.sol";

import { IALMProxy }   from "bloom-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "bloom-alm-controller/src/interfaces/IRateLimits.sol";

import { AllocatorVault }  from 'dss-allocator/src/AllocatorVault.sol';

import { BloomLiquidityLayerContext } from "../../test-harness/BloomLiquidityLayerTests.sol";

interface IInvestmentManager {
    function fulfillCancelDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 fulfillment
    ) external;
    function fulfillCancelRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 shares
    ) external;
    function fulfillDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
    function fulfillRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
}

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface IPSMLike {
    function kiss(address) external;
}

contract BloomEthereum_20250320Test is BloomTestBase {

    address internal constant DEPLOYER                = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;
    address internal constant MORPHO_STEAKHOUSE_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-BLOOM-A";

    IALMProxy         almProxy   = IALMProxy(Ethereum.ALM_PROXY);
    IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

    address constant CENTRIFUGE_JTRSY_VAULT        = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;
    address constant CENTRIFUGE_JTRSY_TOKEN        = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    uint64  constant CENTRIFUGE_JTRSY_POOL_ID      = 4139607887;
    bytes16 constant CENTRIFUGE_JTRSY_TRANCHE_ID   = 0x97aa65f23e7be09fcd62d0554d2e9273;
    uint128 constant CENTRIFUGE_USDC_ASSET_ID      = 242333941209166991950178742833476896417;
    address constant CENTRIFUGE_ROOT               = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;
    address constant CENTRIFUGE_INVESTMENT_MANAGER = 0x427A1ce127b1775e4Cbd4F58ad468B9F832eA7e9;

    constructor() {
        id = "20250417";
    }

    function setUp() public {
        // April 07, 2025
        setupDomain({ mainnetForkBlock: 22217540 });
        deployPayload();

        vm.startPrank(Ethereum.PAUSE_PROXY);
        IPSMLike(address(controller.psm())).kiss(address(almProxy));
        vm.stopPrank();
    }

    function test_almSystemDeployment() public {
        assertEq(almProxy.hasRole(0x0, Ethereum.BLOOM_PROXY),   true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Ethereum.BLOOM_PROXY), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Ethereum.BLOOM_PROXY), true, "incorrect-admin-controller");

        assertEq(almProxy.hasRole(0x0, DEPLOYER),   false, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, DEPLOYER), false, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, DEPLOYER), false, "incorrect-admin-controller");

        assertEq(address(controller.proxy()),                Ethereum.ALM_PROXY,            "incorrect-almProxy");
        assertEq(address(controller.rateLimits()),           Ethereum.ALM_RATE_LIMITS,      "incorrect-rateLimits");
        assertEq(address(controller.vault()),                Ethereum.ALLOCATOR_VAULT,      "incorrect-vault");
        assertEq(address(controller.buffer()),               Ethereum.ALLOCATOR_BUFFER,     "incorrect-buffer");
        assertEq(address(controller.psm()),                  Ethereum.PSM,                  "incorrect-psm");
        assertEq(address(controller.daiUsds()),              Ethereum.DAI_USDS,             "incorrect-daiUsds");
        assertEq(address(controller.cctp()),                 Ethereum.CCTP_TOKEN_MESSENGER, "incorrect-cctpMessenger");
        assertEq(address(controller.dai()),                  Ethereum.DAI,                  "incorrect-dai");
        assertEq(address(controller.susde()),                Ethereum.SUSDE,                "incorrect-susde");
        assertEq(address(controller.ustb()),                 Ethereum.USTB,                 "incorrect-ustb");
        assertEq(address(controller.usdc()),                 Ethereum.USDC,                 "incorrect-usdc");
        assertEq(address(controller.usde()),                 Ethereum.USDE,                 "incorrect-usde");
        assertEq(address(controller.usds()),                 Ethereum.USDS,                 "incorrect-usds");
        assertEq(address(controller.buidlRedeem()),          Ethereum.BUIDL_REDEEM,          "incorrect-buidlRedeem");
        assertEq(address(controller.ethenaMinter()),         Ethereum.ETHENA_MINTER,         "incorrect-ethenaMinter");
        assertEq(address(controller.superstateRedemption()), Ethereum.SUPERSTATE_REDEMPTION, "incorrect-superstateRedemption");

        assertEq(controller.psmTo18ConversionFactor(), 1e12, "incorrect-psmTo18ConversionFactor");

        IVatLike vat = IVatLike(Ethereum.VAT);

        ( uint256 Art, uint256 rate,, uint256 line, ) = vat.ilks(ALLOCATOR_ILK);

        assertEq(Art,  0);
        assertEq(rate, 1e27);
        assertEq(line, 10_000_000e45);

        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.BLOOM_PROXY),  0);
    }

    function test_almSystemInitialization() public {
        executePayload();

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-almProxy");

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-rateLimits");

        assertEq(controller.hasRole(controller.FREEZER(), Ethereum.ALM_FREEZER), true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), Ethereum.ALM_RELAYER), true, "incorrect-relayer-controller");

        assertEq(AllocatorVault(Ethereum.ALLOCATOR_VAULT).wards(Ethereum.ALM_PROXY), 1, "incorrect-vault-ward");

        assertEq(IERC20(Ethereum.USDS).allowance(Ethereum.ALLOCATOR_BUFFER, Ethereum.ALM_PROXY), type(uint256).max, "incorrect-usds-allowance");
    }

    function test_basicRateLimits() public {
        _assertRateLimit({
            key: controller.LIMIT_USDS_MINT(),
            maxAmount: 0,
            slope: 0
        });

        _assertRateLimit({
            key: controller.LIMIT_USDS_TO_USDC(),
            maxAmount: 0,
            slope: 0
        });

        executePayload();

        _assertRateLimit({
            key: controller.LIMIT_USDS_MINT(),
            maxAmount: 10_000_000e18,
            slope: 5_000_000e18 / uint256(1 days)
        });

        _assertRateLimit({
            key: controller.LIMIT_USDS_TO_USDC(),
            maxAmount: 10_000_000e6,
            slope: 5_000_000e6 / uint256(1 days)
        });
    }

    function test_morphoSteakhouseVaultOnboarding() public {
        _testERC4626Onboarding(
            MORPHO_STEAKHOUSE_VAULT,
            5_000_000e6,
            5_000_000e6,
            2_500_000e6 / uint256(1 days)
        );
    }

    function test_fullUSDStoUSDCtoMorphoSteakhouseVaultDepositThenWithdraw() public {
        executePayload();

        vm.startPrank(Ethereum.ALM_RELAYER);

        _assertMainnetAlmProxyBalances({
            usds: 0,
            usdc: 0
        });

        controller.mintUSDS(5_000_000e18);
        _assertMainnetAlmProxyBalances({
            usds: 5_000_000e18,
            usdc: 0
        });

        controller.swapUSDSToUSDC(5_000_000e6);
        _assertMainnetAlmProxyBalances({
            usds: 0,
            usdc: 5_000_000e6
        });

        controller.depositERC4626(MORPHO_STEAKHOUSE_VAULT, 5_000_000e6);
        _assertMainnetAlmProxyBalances({
            usds: 0,
            usdc: 0
        });

        // 1 USDC wei is lost due to rounding
        controller.withdrawERC4626(MORPHO_STEAKHOUSE_VAULT, 5_000_000e6 - 1);
        _assertMainnetAlmProxyBalances({
            usds: 0,
            usdc: 5_000_000e6 - 1
        });

        controller.swapUSDCToUSDS(5_000_000e6 - 1);
        _assertMainnetAlmProxyBalances({
            usds: 5_000_000e18 - 1e12,
            usdc: 0
        });

        controller.burnUSDS(5_000_000e18 - 1e12);
        _assertMainnetAlmProxyBalances({
            usds: 0,
            usdc: 0
        });

        vm.stopPrank();
    }

    function test_centrifugeJTRSYOnboarding() public {
        vm.skip(true);

        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_7540_DEPOSIT(),
            CENTRIFUGE_JTRSY_VAULT
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_7540_REDEEM(),
            CENTRIFUGE_JTRSY_VAULT
        );

        _assertRateLimit(depositKey,  0, 0);
        _assertRateLimit(withdrawKey, 0, 0);

        executePayload();

        _assertRateLimit(depositKey, 5_000_000e6, 2_500_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        IERC20 usdc  = IERC20(Ethereum.USDC);
        IERC20 jtrsy = IERC20(CENTRIFUGE_JTRSY_TOKEN);

        // USDS -> USDC limits are 5m, go a bit below in case some is in use
        uint256 mintAmount = 4_500_000e6;
        vm.startPrank(ctx.relayer);
        controller.mintUSDS(mintAmount * 1e12);
        controller.swapUSDSToUSDC(mintAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  mintAmount);
        assertEq(jtrsy.balanceOf(address(ctx.proxy)), 0);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 5_000_000e6);

        controller.requestDepositERC7540(CENTRIFUGE_JTRSY_VAULT, mintAmount);
        vm.stopPrank();

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 5_000_000e6 - mintAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  0);
        assertEq(jtrsy.balanceOf(address(ctx.proxy)), 0);

        _centrifugeFulfillDepositRequest(mintAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  0);
        assertEq(jtrsy.balanceOf(address(ctx.proxy)), 0);

        vm.prank(ctx.relayer);
        controller.claimDepositERC7540(CENTRIFUGE_JTRSY_VAULT);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  0);
        assertEq(jtrsy.balanceOf(address(ctx.proxy)), mintAmount / 2);

        vm.prank(ctx.relayer);
        controller.requestRedeemERC7540(CENTRIFUGE_JTRSY_VAULT, mintAmount / 2);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  0);
        assertEq(jtrsy.balanceOf(address(ctx.proxy)), 0);

        _centrifugeFulfillRedeemRequest(mintAmount / 2);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  0);
        assertEq(jtrsy.balanceOf(address(ctx.proxy)), 0);

        vm.prank(ctx.relayer);
        controller.claimRedeemERC7540(CENTRIFUGE_JTRSY_VAULT);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  mintAmount);
        assertEq(jtrsy.balanceOf(address(ctx.proxy)), 0);
    }

    function _centrifugeFulfillDepositRequest(uint256 amountUsdc) internal {
        uint128 _amountUsdc = uint128(amountUsdc);
        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        // Fulfill request at price 2.0
        vm.prank(CENTRIFUGE_ROOT);
        IInvestmentManager(CENTRIFUGE_INVESTMENT_MANAGER).fulfillDepositRequest(
            CENTRIFUGE_JTRSY_POOL_ID,
            CENTRIFUGE_JTRSY_TRANCHE_ID,
            address(ctx.proxy),
            CENTRIFUGE_USDC_ASSET_ID,
            _amountUsdc,
            _amountUsdc / 2
        );
    }

    function _centrifugeFulfillRedeemRequest(uint256 amountJtrsy) internal {
        uint128 _amountJtrsy = uint128(amountJtrsy);
        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        // Fulfill request at price 2.0
        vm.prank(CENTRIFUGE_ROOT);
        IInvestmentManager(CENTRIFUGE_INVESTMENT_MANAGER).fulfillRedeemRequest(
            CENTRIFUGE_JTRSY_POOL_ID,
            CENTRIFUGE_JTRSY_TRANCHE_ID,
            address(ctx.proxy),
            CENTRIFUGE_USDC_ASSET_ID,
            _amountJtrsy * 2,
            _amountJtrsy
        );
    }

}
