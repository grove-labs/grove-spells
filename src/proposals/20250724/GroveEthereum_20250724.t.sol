// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { console } from "forge-std/console.sol";

import { Ethereum as GroveContracts } from "lib/grove-address-registry/src/Ethereum.sol";
import { Ethereum as SparkContracts } from "lib/spark-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";


import { GroveLiquidityLayerContext, CentrifugeConfig } from "../../test-harness/GroveLiquidityLayerTests.sol";

import "src/test-harness/GroveTestBase.sol";

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

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function Line() external view returns (uint256);
    function file(bytes32, uint256) external;
    function file(bytes32, bytes32, uint256) external;
}

interface AutoLineLike {
    function exec(bytes32) external;
    function ilks(bytes32) external view returns (uint256, uint256, uint48, uint48, uint48);
}

contract GroveEthereum_20250724Test is GroveTestBase {

    address internal constant CENTRIFUGE_JTRSY        = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;
    address internal constant CENTRIFUGE_JTRSY_SHARES = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address internal constant BUIDL                   = 0x6a9DA2D710BB9B700acde7Cb81F10F1fF8C89041;
    address internal constant BUIDL_DEPOSIT           = 0xD1917664bE3FdAea377f6E8D5BF043ab5C3b1312;
    address internal constant BUIDL_REDEEM            = 0x8780Dd016171B91E4Df47075dA0a947959C34200;
    address internal constant BUIDL_ADMIN             = 0xe01605f6b6dC593b7d2917F4a0940db2A625b09e;
    address internal constant MORPHO_STEAKHOUSE_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-BLOOM-A";

    uint256 internal constant JTRSY_USDS_MINT_AMOUNT = 404_016_484e18;
    uint256 internal constant RAY = 10 ** 27;

    IVatLike vat = IVatLike(GroveContracts.VAT);

    uint256 totalUsdsMintAmount;

    constructor() {
        id = "20250724";
    }

    function setUp() public {
        // July 8, 2025
        setupDomain({ mainnetForkBlock: 22875932 });
        deployPayload();

        (uint256 currentArt,,,,) = vat.ilks(ALLOCATOR_ILK);

        uint256 buidlUsdsMintAmount = IERC20(BUIDL).balanceOf(SparkContracts.ALM_PROXY) * 1e12;

        totalUsdsMintAmount = buidlUsdsMintAmount + JTRSY_USDS_MINT_AMOUNT;

        uint256 neededLine = (currentArt + totalUsdsMintAmount) * RAY;

        // Sky PAUSE_PROXY sets line to allow for the mint
        vm.startPrank(GroveContracts.PAUSE_PROXY);
        vat.file(ALLOCATOR_ILK, "line", neededLine);
        vm.stopPrank();
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
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        MainnetController controller = MainnetController(GroveContracts.ALM_CONTROLLER);

        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            controller.LIMIT_ASSET_TRANSFER(),
            GroveContracts.USDC,
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

        AutoLineLike(GroveContracts.AUTO_LINE).exec(ALLOCATOR_ILK);

        _assertRateLimit(depositKey, 50_000_000e6, 50_000_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        IERC20 usdc  = IERC20(GroveContracts.USDC);
        IERC20 buidl = IERC20(BUIDL);

        // Line can be raised to 100m, but currently set to 50m and will be raised to 100m automatically when used up
        uint256 mintAmount = 45_000_000e6;
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

    function test_sendUSDSToSpark() public {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        (uint256 beforeMintArt,,, uint256 beforeMintLine,) = vat.ilks(ALLOCATOR_ILK);

        uint256 totalSparkJtrsyBalance = IERC20(CENTRIFUGE_JTRSY_SHARES).balanceOf(SparkContracts.ALM_PROXY);
        uint256 totalSparkBuidlBalance = IERC20(                  BUIDL).balanceOf(SparkContracts.ALM_PROXY);

        uint256 beforeSparkProxyUsdsBalance = IERC20(GroveContracts.USDS).balanceOf(SparkContracts.ALM_PROXY);

        // Assert Grove proxy has no BUIDL or JTRSY
        assertEq(IERC20(CENTRIFUGE_JTRSY_SHARES).balanceOf(address(ctx.proxy)), 0);
        assertEq(IERC20(                  BUIDL).balanceOf(address(ctx.proxy)), 0);

        // Mint USDS and send to Spark
        executePayload();

        // Assert Spark ALM Proxy received the minted USDS
        uint256 afterSparkProxyUsdsBalance = IERC20(GroveContracts.USDS).balanceOf(SparkContracts.ALM_PROXY);
        assertEq(afterSparkProxyUsdsBalance, beforeSparkProxyUsdsBalance + totalUsdsMintAmount);

        // Spark sends BUIDL and JTRSY to Grove proxy
        vm.startPrank(SparkContracts.ALM_PROXY);
        IERC20(CENTRIFUGE_JTRSY_SHARES).transfer(address(ctx.proxy), totalSparkJtrsyBalance);
        IERC20(                  BUIDL).transfer(address(ctx.proxy), totalSparkBuidlBalance);
        vm.stopPrank();

        (uint256 afterMintArt,,, uint256 afterMintLine,) = vat.ilks(ALLOCATOR_ILK);

        // Assert line stays the same and art increases by the mint amount
        assertEq(afterMintArt,  beforeMintArt + totalUsdsMintAmount);
        assertEq(afterMintLine, beforeMintLine);

        // Assert Grove proxy has all of the BUIDL and JTRSY from Spark
        assertEq(IERC20(CENTRIFUGE_JTRSY_SHARES).balanceOf(address(ctx.proxy)), totalSparkJtrsyBalance);
        assertEq(IERC20(                  BUIDL).balanceOf(address(ctx.proxy)), totalSparkBuidlBalance);

        // Assert Spark has no BUIDL or JTRSY
        assertEq(IERC20(CENTRIFUGE_JTRSY_SHARES).balanceOf(SparkContracts.ALM_PROXY), 0);
        assertEq(IERC20(                  BUIDL).balanceOf(SparkContracts.ALM_PROXY), 0);

        // AutoLine raises the line to the gap
        AutoLineLike(GroveContracts.AUTO_LINE).exec(ALLOCATOR_ILK);

        (,,, uint256 afterExecLine,) = vat.ilks(ALLOCATOR_ILK);

        (,uint256 gap,,,) = AutoLineLike(GroveContracts.AUTO_LINE).ilks(ALLOCATOR_ILK);

        // Assert line increases by the gap after the mint
        assertEq(afterExecLine, afterMintLine + gap);
    }

}
