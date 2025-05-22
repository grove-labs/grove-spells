// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum as BloomContracts } from "lib/bloom-address-registry/src/Ethereum.sol";
import { Ethereum as SparkContracts } from "lib/spark-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/bloom-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

import { BloomLiquidityLayerContext, CentrifugeConfig } from "../../test-harness/BloomLiquidityLayerTests.sol";

import "src/test-harness/BloomTestBase.sol";

interface IBuidlLike is IERC20 {
    function issueTokens(address to, uint256 amount) external;
}

interface ICentrifugeRoot {
    function endorse(address user) external;
}

interface ISuperstateToken is IERC20 {
    function calculateSuperstateTokenOut(uint256, address)
        external view returns (uint256, uint256, uint256);
}

contract BloomEthereum_20250612Test is BloomTestBase {

    address internal constant CENTRIFUGE_JTRSY = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;
    address internal constant BUIDL            = 0x6a9DA2D710BB9B700acde7Cb81F10F1fF8C89041;
    address internal constant BUIDL_DEPOSIT    = 0xD1917664bE3FdAea377f6E8D5BF043ab5C3b1312;
    address internal constant BUIDL_REDEEM     = 0x8780Dd016171B91E4Df47075dA0a947959C34200;
    address internal constant BUIDL_ADMIN      = 0xe01605f6b6dC593b7d2917F4a0940db2A625b09e;

    constructor() {
        id = "20250612";
    }

    function setUp() public {
        // May 5, 2025
        setupDomain({ mainnetForkBlock: 22418039 });
        deployPayload();
    }

    function test_centrifugeJTRSYOnboarding() public {
        _testCentrifugeOnboarding(
            CENTRIFUGE_JTRSY,
            50_000_000e6,
            50_000_000e6,
            50_000_000e6 / uint256(1 days)
        );
    }

    function test_blackrockBUIDLOnboarding() public {
        // Skip before proper whitelisting is performed
        vm.skip(true);

        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        MainnetController controller = MainnetController(BloomContracts.ALM_CONTROLLER);

        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            controller.LIMIT_ASSET_TRANSFER(),
            BloomContracts.USDC,
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

        _assertRateLimit(depositKey, 50_000_000e6, 50_000_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        IERC20 usdc  = IERC20(BloomContracts.USDC);
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

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 50_000_000e6);

        controller.transferAsset(address(usdc), BUIDL_DEPOSIT, mintAmount);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(ctx.proxy)), 0);
        assertEq(usdc.balanceOf(BUIDL_DEPOSIT),      buidlDepositBalance + mintAmount);

        assertEq(buidl.balanceOf(address(ctx.proxy)), 0);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 50_000_000e6 - mintAmount);

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

    function test_superstateUSTBOnboarding() public {
        // Skip before proper whitelisting is performed
        vm.skip(true);

        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        MainnetController controller = MainnetController(BloomContracts.ALM_CONTROLLER);

        IERC20 usdc           = IERC20(BloomContracts.USDC);
        ISuperstateToken ustb = ISuperstateToken(BloomContracts.USTB);

        bytes32 depositKey        = controller.LIMIT_SUPERSTATE_SUBSCRIBE();
        bytes32 withdrawKey       = controller.LIMIT_SUPERSTATE_REDEEM();
        bytes32 offchainRedeemKey = RateLimitHelpers.makeAssetDestinationKey(
            controller.LIMIT_ASSET_TRANSFER(),
            address(ustb),
            address(ustb)
        );

        _assertRateLimit(depositKey,        0, 0);
        _assertRateLimit(withdrawKey,       0, 0);
        _assertRateLimit(offchainRedeemKey, 0, 0);

        executePayload();

        _assertRateLimit(depositKey, 50_000_000e6, 50_000_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);
        _assertRateLimit(offchainRedeemKey, type(uint256).max, 0);

        // Line can be raised to 100m, but currently set to 50m and will be raised to 100m automatically when used up
        uint256 mintAmount = 50_000_000e6;
        vm.startPrank(ctx.relayer);
        controller.mintUSDS(mintAmount * 1e12);
        controller.swapUSDSToUSDC(mintAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)), mintAmount);
        assertEq(ustb.balanceOf(address(ctx.proxy)), 0);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 50_000_000e6);

        (uint256 ustbShares,,) = ustb.calculateSuperstateTokenOut(mintAmount, address(usdc));

        controller.subscribeSuperstate(mintAmount);
        vm.stopPrank();

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 50_000_000e6 - mintAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)), 0);
        assertEq(ustb.balanceOf(address(ctx.proxy)), ustbShares);

        // Doing a smaller redeem because there is not necessarily enough liquidity
        vm.prank(ctx.relayer);
        controller.redeemSuperstate(ustbShares / 100);

        assertApproxEqAbs(usdc.balanceOf(address(ctx.proxy)), mintAmount * 1/100, 100);
        assertApproxEqAbs(ustb.balanceOf(address(ctx.proxy)), ustbShares * 99/100, 1);

        uint256 totalSupply = ustb.totalSupply();

        // You can always burn the whole amount by doing it offchain
        uint256 ustbBalance = ustb.balanceOf(address(ctx.proxy));
        vm.prank(ctx.relayer);
        controller.transferAsset(address(ustb), address(ustb), ustbBalance);

        // Transferring to token contract burns the amount
        assertEq(ustb.totalSupply(), totalSupply - ustbBalance);

        // USDC will come back async
        assertApproxEqAbs(usdc.balanceOf(address(ctx.proxy)), mintAmount * 1/100, 100);
        assertEq(ustb.balanceOf(address(ctx.proxy)), 0);
    }

    function test_sparkUSDSTransfers() public {
        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        MainnetController controller = MainnetController(BloomContracts.ALM_CONTROLLER);

        bytes32 key = RateLimitHelpers.makeAssetDestinationKey(
            controller.LIMIT_ASSET_TRANSFER(),
            BloomContracts.USDS,
            SparkContracts.ALM_PROXY
        );

        _assertRateLimit(key, 0, 0);

        executePayload();

        _assertRateLimit(key, 50_000_000e18, 50_000_000e18 / uint256(1 days));

        assertEq(IERC20(BloomContracts.USDS).balanceOf(address(ctx.proxy)), 0);

        uint256 sparkProxyUsdsBalanceBefore = IERC20(SparkContracts.USDS).balanceOf(address(ctx.proxy));

        vm.startPrank(ctx.relayer);
        controller.mintUSDS(50_000_000e18);
        controller.transferAsset(BloomContracts.USDS, SparkContracts.ALM_PROXY, 50_000_000e18);
        vm.stopPrank();

        assertEq(IERC20(BloomContracts.USDS).balanceOf(address(ctx.proxy)), 0);
        assertEq(IERC20(BloomContracts.USDS).balanceOf(SparkContracts.ALM_PROXY), sparkProxyUsdsBalanceBefore + 50_000_000e18);
    }

}
