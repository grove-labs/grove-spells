// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/ChainId.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/GroveLiquidityLayerTests.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface AutoLineLike {
    function exec(bytes32) external;
}

contract GroveEthereum_20251016_Test is GroveTestBase {

    address internal constant ETHEREUM_PAYLOAD = 0xF2A28fb43D5d3093904B889538277fB175B42Ece;

    address internal constant FALCON_X_DEPOSIT = 0xD94F9ef3395BBE41C1f05ced3C9a7dc520D08036;

    uint256 internal constant FALCON_X_USDC_TRANSFER_RATE_LIMIT_MAX   = 50_000_000e6;
    uint256 internal constant FALCON_X_USDC_TRANSFER_RATE_LIMIT_SLOPE = 50_000_000e6 / uint256(1 days);

    constructor() {
        id = "20251016";
    }

    function setUp() public {
        setupDomains("2025-10-13T17:43:00Z");

        chainData[ChainIdUtils.Ethereum()].payload = ETHEREUM_PAYLOAD;
    }

    function test_ETHEREUM_onboardFalconXDeposits() public onChain(ChainIdUtils.Ethereum()) {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            controller.LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            FALCON_X_DEPOSIT
        );

        _assertZeroRateLimit(depositKey);

        executeAllPayloadsAndBridges();

        _assertRateLimit(
            depositKey,
            FALCON_X_USDC_TRANSFER_RATE_LIMIT_MAX,
            FALCON_X_USDC_TRANSFER_RATE_LIMIT_SLOPE
        );

        IERC20 usdc = IERC20(Ethereum.USDC);

        uint256 depositAmount = FALCON_X_USDC_TRANSFER_RATE_LIMIT_MAX;

        AutoLineLike(Ethereum.AUTO_LINE).exec(GROVE_ALLOCATOR_ILK);

        vm.startPrank(ctx.relayer);
        controller.mintUSDS(depositAmount * 1e12);
        controller.swapUSDSToUSDC(depositAmount);
        vm.stopPrank();

        uint256 initialFalconXDepositBalance = usdc.balanceOf(FALCON_X_DEPOSIT);

        assertEq(usdc.balanceOf(address(ctx.proxy)), depositAmount);
        assertEq(usdc.balanceOf(FALCON_X_DEPOSIT),   initialFalconXDepositBalance);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), FALCON_X_USDC_TRANSFER_RATE_LIMIT_MAX);

        vm.prank(ctx.relayer);
        controller.transferAsset(address(usdc), FALCON_X_DEPOSIT, depositAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)), 0);
        assertEq(usdc.balanceOf(FALCON_X_DEPOSIT),   initialFalconXDepositBalance + depositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 0);

        vm.warp(block.timestamp + 1 days + 1 seconds);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), FALCON_X_USDC_TRANSFER_RATE_LIMIT_MAX);
    }

}
