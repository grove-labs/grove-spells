// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/BloomTestBase.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/bloom-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/bloom-alm-controller/src/MainnetController.sol";

import { RateLimitHelpers } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

import { BloomLiquidityLayerContext, CentrifugeConfig } from "../../test-harness/BloomLiquidityLayerTests.sol";

interface IBuidlLike is IERC20 {
    function issueTokens(address to, uint256 amount) external;
}

contract BloomEthereum_20250529Test is BloomTestBase {

    address internal constant CENTRIFUGE_JTRSY_VAULT = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;

    address internal constant BUIDL         = 0x6a9DA2D710BB9B700acde7Cb81F10F1fF8C89041;
    address internal constant BUIDL_DEPOSIT = 0xD1917664bE3FdAea377f6E8D5BF043ab5C3b1312;
    address internal constant BUIDL_REDEEM  = 0x8780Dd016171B91E4Df47075dA0a947959C34200;
    address internal constant BUIDL_ADMIN   = 0xe01605f6b6dC593b7d2917F4a0940db2A625b09e;

    constructor() {
        id = "20250529";
    }

    function setUp() public {
        // May 2, 2025
        setupDomain({ mainnetForkBlock: 22396975 });
        deployPayload();
    }

    function test_centrifugeVaultOnboarding() public {
        _testCentrifugeOnboarding(
            CENTRIFUGE_JTRSY_VAULT,
            100_000_000e6,
            100_000_000e6,
            50_000_000e6 / uint256(1 days)
        );
    }

    function test_blackrockBUIDLOnboarding() public {
        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            controller.LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            BUIDL_DEPOSIT
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetDestinationKey(
            controller.LIMIT_ASSET_TRANSFER(),
            BUIDL,
            BUIDL_REDEEM
        );

        _assertRateLimit(depositKey,  0, 0);
        _assertRateLimit(withdrawKey, 0, 0);

        executePayload();

        _assertRateLimit(depositKey,  100_000_000e6,     50_000_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        IERC20 usdc  = IERC20(Ethereum.USDC);
        IERC20 buidl = IERC20(BUIDL);

        // Line can be raised to 100m, but currently set to 50m and will be raised to 100m automatically when used up
        uint256 mintAmount = 50_000_000e6;
        vm.startPrank(ctx.relayer);
        controller.mintUSDS(mintAmount * 1e12);
        controller.swapUSDSToUSDC(mintAmount);

        uint256 buidlDepositBalance = usdc.balanceOf(BUIDL_DEPOSIT);
        uint256 buidlRedeemBalance  = buidl.balanceOf(BUIDL_REDEEM);

        assertEq(usdc.balanceOf(address(ctx.proxy)), mintAmount);
        assertEq(usdc.balanceOf(BUIDL_DEPOSIT),      buidlDepositBalance);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 100_000_000e6);

        controller.transferAsset(address(usdc), BUIDL_DEPOSIT, mintAmount);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(ctx.proxy)), 0);
        assertEq(usdc.balanceOf(BUIDL_DEPOSIT),      buidlDepositBalance + mintAmount);

        assertEq(buidl.balanceOf(address(ctx.proxy)), 0);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 100_000_000e6 - mintAmount);

        // Emulate BUIDL deposit
        vm.startPrank(BUIDL_ADMIN);
        IBuidlLike(BUIDL).issueTokens(address(ctx.proxy), mintAmount);
        vm.stopPrank();

        assertEq(buidl.balanceOf(address(ctx.proxy)), mintAmount);
        assertEq(buidl.balanceOf(BUIDL_REDEEM),       buidlRedeemBalance);

        vm.prank(ctx.relayer);
        controller.transferAsset(address(buidl), BUIDL_REDEEM, mintAmount);

        assertEq(buidl.balanceOf(address(ctx.proxy)), 0);
        assertEq(buidl.balanceOf(BUIDL_REDEEM),       buidlRedeemBalance + mintAmount);
    }

}
