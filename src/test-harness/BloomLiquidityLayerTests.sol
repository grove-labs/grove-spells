// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { Ethereum } from "bloom-address-registry/Ethereum.sol";

import { IALMProxy }         from "bloom-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "bloom-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "bloom-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "bloom-alm-controller/src/RateLimitHelpers.sol";

import { SpellRunner } from "./SpellRunner.sol";

struct BloomLiquidityLayerContext {
    address     controller;
    IALMProxy   proxy;
    IRateLimits rateLimits;
    address     relayer;
    address     freezer;
}

struct CentrifugeConfig {
    address centrifugeRoot;
    address centrifugeInvestmentManager;
    bytes16 centrifugeTrancheId;
    uint64  centrifugePoolId;
    uint128 centrifugeAssetId;
}

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

abstract contract BloomLiquidityLayerTests is SpellRunner {

    function _getBloomLiquidityLayerContext() internal pure returns(BloomLiquidityLayerContext memory ctx) {
        ctx = BloomLiquidityLayerContext(
            Ethereum.ALM_CONTROLLER,
            IALMProxy(Ethereum.ALM_PROXY),
            IRateLimits(Ethereum.ALM_RATE_LIMITS),
            Ethereum.ALM_RELAYER,
            Ethereum.ALM_FREEZER
        );
    }

   function _assertRateLimit(
       bytes32 key,
       uint256 maxAmount,
       uint256 slope
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getBloomLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, maxAmount);
        assertEq(rateLimit.slope,     slope);
    }

   function _assertUnlimitedRateLimit(
       bytes32 key
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getBloomLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, type(uint256).max);
        assertEq(rateLimit.slope,     0);
    }

   function _assertRateLimit(
       bytes32 key,
       uint256 maxAmount,
       uint256 slope,
       uint256 lastAmount,
       uint256 lastUpdated
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getBloomLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  lastAmount);
        assertEq(rateLimit.lastUpdated, lastUpdated);
    }

    function _testERC4626Onboarding(
        address vault,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();
        bool unlimitedDeposit = depositMax == type(uint256).max;

        // Note: ERC4626 signature is the same for mainnet and foreign
        deal(IERC4626(vault).asset(), address(ctx.proxy), expectedDepositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_4626_DEPOSIT(),
            vault
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_4626_WITHDRAW(),
            vault
        );

        _assertRateLimit(depositKey, 0, 0);
        _assertRateLimit(withdrawKey, 0, 0);

        // TODO: Uncomment this once the relayer going to be properly set before the payload execution
        // vm.prank(ctx.relayer);
        // vm.expectRevert("RateLimits/zero-maxAmount");
        // MainnetController(ctx.controller).depositERC4626(vault, expectedDepositAmount);

        executePayload();

        _assertRateLimit(depositKey, depositMax, depositSlope);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        if (!unlimitedDeposit) {
            vm.prank(ctx.relayer);
            vm.expectRevert("RateLimits/rate-limit-exceeded");
            MainnetController(ctx.controller).depositERC4626(vault, depositMax + 1);
        }

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  depositMax);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).depositERC4626(vault, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).withdrawERC4626(vault, expectedDepositAmount / 2);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        if (!unlimitedDeposit) {
            // Do some sanity checks on the slope
            // This is to catch things like forgetting to divide to a per-second time, etc

            // We assume it takes at least 1 day to recharge to max
            uint256 dailySlope = depositSlope * 1 days;
            assertLe(dailySlope, depositMax);

            // It shouldn"t take more than 30 days to recharge to max
            uint256 monthlySlope = depositSlope * 30 days;
            assertGe(monthlySlope, depositMax);
        }
    }

    function _testCentrifugeOnboarding(
        address centrifugeVault,
        address centrifugeToken,
        CentrifugeConfig memory centrifugeConfig,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) public {
        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        deal(IERC4626(centrifugeVault).asset(), address(ctx.proxy), expectedDepositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_7540_DEPOSIT(),
            centrifugeVault
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetKey(
            MainnetController(ctx.controller).LIMIT_7540_REDEEM(),
            centrifugeVault
        );

        _assertRateLimit(depositKey,  0, 0);
        _assertRateLimit(redeemKey, 0, 0);

        executePayload();

        _assertRateLimit(depositKey, depositMax, depositSlope);
        _assertRateLimit(redeemKey, type(uint256).max, 0);

        IERC20 usdc       = IERC20(Ethereum.USDC);
        IERC20 vaultToken = IERC20(centrifugeToken);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       expectedDepositAmount);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeVault, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax - expectedDepositAmount);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        _centrifugeFulfillDepositRequest(
            centrifugeConfig,
            expectedDepositAmount
        );

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeVault);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), expectedDepositAmount / 2);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestRedeemERC7540(centrifugeVault, expectedDepositAmount / 2);

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        _centrifugeFulfillRedeemRequest(
            centrifugeConfig,
            expectedDepositAmount / 2
        );

        assertEq(usdc.balanceOf(address(ctx.proxy)),       0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimRedeemERC7540(centrifugeVault);

        assertEq(usdc.balanceOf(address(ctx.proxy)),  expectedDepositAmount);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), 0);
    }

    function _centrifugeFulfillDepositRequest(
        CentrifugeConfig memory config,
        uint256 assetAmount
    ) internal {
        uint128 _assetAmount = uint128(assetAmount);
        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        // Fulfill request at price 2.0
        vm.prank(config.centrifugeRoot);
        IInvestmentManager(config.centrifugeInvestmentManager).fulfillDepositRequest(
            config.centrifugePoolId,
            config.centrifugeTrancheId,
            address(ctx.proxy),
            config.centrifugeAssetId,
            _assetAmount,
            _assetAmount / 2
        );
    }

    function _centrifugeFulfillRedeemRequest(
        CentrifugeConfig memory config,
        uint256 tokenAmount
    ) internal {
        uint128 _tokenAmount = uint128(tokenAmount);
        BloomLiquidityLayerContext memory ctx = _getBloomLiquidityLayerContext();

        // Fulfill request at price 2.0
        vm.prank(config.centrifugeRoot);
        IInvestmentManager(config.centrifugeInvestmentManager).fulfillRedeemRequest(
            config.centrifugePoolId,
            config.centrifugeTrancheId,
            address(ctx.proxy),
            config.centrifugeAssetId,
            _tokenAmount * 2,
            _tokenAmount
        );
    }

}
