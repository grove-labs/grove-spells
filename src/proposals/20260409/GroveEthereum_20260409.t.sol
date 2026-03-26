// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { ChainIdUtils }               from "src/libraries/helpers/ChainId.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/CommonTestBase.sol";
import { GroveTestBase }              from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260409_Test is GroveTestBase {

    address internal constant MAPLE_SYRUP_USDC              = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address internal constant MAPLE_POOL_PERMISSION_MANAGER = 0x7aD5fFa5fdF509E30186F4609c2f6269f4B6158F;

    constructor() {
        id = "20260409";
    }

    function setUp() public {
        setupDomains("2026-03-24T16:00:00Z");

        deployPayloads();
    }

    function _registerAddressesForDocumentation() internal override {
        _registerAddress(MAPLE_SYRUP_USDC,          "MAPLE_SYRUP_USDC");
        _registerAddress(Ethereum.CENTRIFUGE_JTRSY, "CENTRIFUGE_JTRSY");
    }

    function test_ETHEREUM_onboardMapleSyrupUsdc() public onChain(ChainIdUtils.Ethereum()) {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        uint256 depositAmount = 50_000_000e6;

        deal2(IERC4626(MAPLE_SYRUP_USDC).asset(), address(ctx.proxy), depositAmount);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            MAPLE_SYRUP_USDC
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_WITHDRAW,
            MAPLE_SYRUP_USDC
        );

        _assertZeroRateLimit(depositKey);
        _assertZeroRateLimit(withdrawKey);

        vm.prank(ctx.relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        MainnetController(ctx.controller).depositERC4626(MAPLE_SYRUP_USDC, depositAmount);

        executeAllPayloadsAndBridges();

        ctx = _getGroveLiquidityLayerContext();

        uint256 setExchangeRate      = MainnetController(ctx.controller).maxExchangeRates(MAPLE_SYRUP_USDC);
        uint256 expectedExchangeRate = MainnetController(ctx.controller).EXCHANGE_RATE_PRECISION() * 3e6 / 1e6;
        assertEq(setExchangeRate, expectedExchangeRate);

        _assertRateLimit(depositKey, 50_000_000e6, 50_000_000e6 / uint256(1 days));
        _assertZeroRateLimit(withdrawKey);

        vm.prank(ctx.relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        MainnetController(ctx.controller).depositERC4626(MAPLE_SYRUP_USDC, 50_000_000e6 + 1);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 50_000_000e6);

        // Maple's pool permission manager must whitelist the ALM proxy for deposits.
        // In production this is done by Maple governance; here we mock it for testing.
        vm.mockCall(
            MAPLE_POOL_PERMISSION_MANAGER,
            abi.encodeWithSignature("canCall(bytes32,address,bytes)"),
            abi.encode(true, "")
        );

        uint256 sharesBefore = IERC4626(MAPLE_SYRUP_USDC).balanceOf(address(ctx.proxy));

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).depositERC4626(MAPLE_SYRUP_USDC, depositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 0);

        uint256 sharesReceived = IERC4626(MAPLE_SYRUP_USDC).balanceOf(address(ctx.proxy)) - sharesBefore;

        assertGt(sharesReceived, 0);
        assertEq(sharesReceived, IERC4626(MAPLE_SYRUP_USDC).previewDeposit(depositAmount));
    }

    function test_ETHEREUM_increaseJtrsyDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        _testCentrifugeV3DepositRateLimitIncrease({
            centrifugeVault      : Ethereum.CENTRIFUGE_JTRSY,
            previousDepositMax   : 50_000_000e6,
            previousDepositSlope : 50_000_000e6 / uint256(1 days),
            newDepositMax        : 500_000_000e6,
            newDepositSlope      : 500_000_000e6 / uint256(1 days)
        });
    }

    function test_ETHEREUM_increasePsmUsdsUsdcSwapRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        bytes32 psmKey = GroveLiquidityLayerHelpers.LIMIT_USDS_TO_USDC;

        _assertRateLimit(psmKey, 100_000_000e6, 50_000_000e6 / uint256(1 days));

        executeAllPayloadsAndBridges();

        ctx = _getGroveLiquidityLayerContext();

        _assertRateLimit(psmKey, 500_000_000e6, 500_000_000e6 / uint256(1 days));

        uint256 swapAmount = 500_000_000e6; // 500M USDC

        deal2(Ethereum.USDS, address(ctx.proxy), swapAmount * 1e12);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).swapUSDSToUSDC(swapAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(psmKey), 500_000_000e6 - swapAmount);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).swapUSDCToUSDS(swapAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(psmKey), 500_000_000e6);

    }

}
