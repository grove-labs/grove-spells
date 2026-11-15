// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Vm }     from "forge-std/Vm.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { RecordedLogs } from "xchain-helpers/testing/utils/RecordedLogs.sol";

import { GroveLiquidityLayerContext, CommonALMTestBase } from "../CommonALMTestBase.sol";

abstract contract ERC20TestingBase is CommonALMTestBase {

    bytes32 private constant TRANSFER_EVENT = keccak256("Transfer(address,address,uint256)");

    /**********************************************************************************************/
    /*** Testing functions                                                                      ***/
    /**********************************************************************************************/

    function _testDirectTokenTransferOnboarding(
        address token,
        address destination,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        deal2(token, address(ctx.proxy), expectedDepositAmount);

        __runDirectTokenTransferOnboardingTests(token, destination, expectedDepositAmount, depositMax, depositSlope);
    }

    function _testUnlimitedDirectTokenTransferOnboarding(
        address token,
        address destination,
        uint256 expectedDepositAmount
    ) internal {
        _testDirectTokenTransferOnboarding(token, destination, expectedDepositAmount, type(uint256).max, 0);
    }

    function _testDirectUsdcTransferOnboarding(
        address usdc,
        address destination,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        uint256 initialUsdcBalance = IERC20(usdc).balanceOf(address(ctx.proxy));

        if (initialUsdcBalance > expectedDepositAmount) {
            uint256 usdcSurplus = initialUsdcBalance - expectedDepositAmount;

            vm.startPrank(ctx.relayer);
            MainnetController(ctx.controller).swapUSDCToUSDS(usdcSurplus);
            MainnetController(ctx.controller).burnUSDS(usdcSurplus * 1e12);
            vm.stopPrank();

        }

        if (initialUsdcBalance < expectedDepositAmount) {
            uint256 usdcDeficit = expectedDepositAmount - initialUsdcBalance;

            vm.startPrank(ctx.relayer);
            MainnetController(ctx.controller).mintUSDS(usdcDeficit * 1e12);
            MainnetController(ctx.controller).swapUSDSToUSDC(usdcDeficit);
            vm.stopPrank();
        }

        __runDirectTokenTransferOnboardingTests(
            usdc,
            destination,
            expectedDepositAmount,
            depositMax,
            depositSlope
        );
    }

    function _getRecordedLogsLength() internal returns (uint256) {
        return RecordedLogs.getLogs().length;
    }

    function _assertErc20TransferEvents(
        address token,
        address from,
        address to,
        uint256 logsBefore,
        uint256[] memory expectedAmounts
    ) internal {
        Vm.Log[] memory logs = RecordedLogs.getLogs();

        bytes32 fromTopic = bytes32(uint256(uint160(from)));
        bytes32 toTopic   = bytes32(uint256(uint160(to)));

        bool[] memory matched = new bool[](expectedAmounts.length);
        uint256 transferCount;

        for (uint256 i = logsBefore; i < logs.length; ++i) {
            if (logs[i].emitter != token || logs[i].topics.length != 3) continue;
            if (
                logs[i].topics[0] != TRANSFER_EVENT ||
                logs[i].topics[1] != fromTopic ||
                logs[i].topics[2] != toTopic
            ) continue;

            uint256 amount = abi.decode(logs[i].data, (uint256));
            bool found;

            for (uint256 j; j < expectedAmounts.length; ++j) {
                if (matched[j] || amount != expectedAmounts[j]) continue;

                matched[j] = true;
                found      = true;
                break;
            }

            assertTrue(found, "unexpected-erc20-transfer");
            ++transferCount;
        }

        assertEq(transferCount, expectedAmounts.length, "unexpected-erc20-transfer-count");

        for (uint256 i; i < matched.length; ++i) {
            assertTrue(matched[i], "missing-erc20-transfer");
        }
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

    function __runDirectTokenTransferOnboardingTests(
        address token,
        address destination,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) private {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        bool unlimitedDeposit = depositMax == type(uint256).max;

        bytes32 depositKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(ctx.controller).LIMIT_ASSET_TRANSFER(),
            token,
            destination
        );

        _assertZeroRateLimit(depositKey);

        executeAllPayloadsAndBridges();

        ctx = _getGroveLiquidityLayerContext();

        _assertRateLimit(depositKey, depositMax, depositSlope);

        if (!unlimitedDeposit) {
            vm.prank(ctx.relayer);
            vm.expectRevert("RateLimits/rate-limit-exceeded");
            MainnetController(ctx.controller).transferAsset(token, destination, depositMax + 1);
        }

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax, "current-rate-limit-not-correct");

        uint256 initialDestinationBalance = IERC20(token).balanceOf(destination);

        assertEq(IERC20(token).balanceOf(address(ctx.proxy)), expectedDepositAmount,     "proxy-balance-not-correct");
        assertEq(IERC20(token).balanceOf(destination),        initialDestinationBalance, "destination-balance-not-correct");

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).transferAsset(token, destination, expectedDepositAmount);

        assertEq(
            ctx.rateLimits.getCurrentRateLimit(depositKey),
            unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount,
            "current-rate-limit-not-correct"
        );

        assertEq(IERC20(token).balanceOf(address(ctx.proxy)), 0,                                                 "proxy-balance-not-correct");
        assertEq(IERC20(token).balanceOf(destination),        initialDestinationBalance + expectedDepositAmount, "destination-balance-not-correct");

        if (!unlimitedDeposit) {
            vm.warp(block.timestamp + 1 days + 1 seconds);

            assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);
        }
    }

}
