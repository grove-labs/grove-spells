// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { IRateLimits }       from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { ChainIdUtils }               from "src/libraries/helpers/ChainId.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveLiquidityLayerContext, CommonTestBase } from "../CommonTestBase.sol";

enum RequestCallbackType {
    Invalid,
    ApprovedDeposits,
    IssuedShares,
    RevokedShares,
    FulfilledDepositRequest,
    FulfilledRedeemRequest
}

struct CentrifugeV3Config {
    address centrifugeVault;
    address centrifugeRoot;
    address centrifugeManager;
    address centrifugeAsset;
    address centrifugeSpoke;
    bytes16 centrifugeScId;
    uint64  centrifugePoolId;
    uint128 centrifugeAssetId;
}

interface ICentrifugeV3Vault {
    function asset()   external view returns (address);
    function share()   external view returns (address);
    function manager() external view returns (address);
    function poolId()  external view returns (uint64);
    function scId()    external view returns (bytes16);
    function root()    external view returns (address);
}

interface ICentrifugeV3ShareLike {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function hook() external view returns (address);
    function file(bytes32 what, address data) external;
}

interface IFreelyTransferableHookLike {
    function updateMember(address token, address user, uint64 validUntil) external;
}

interface IAsyncRedeemManagerLike {
    function callback(uint64 poolId, bytes16 scId, uint128 assetId, bytes calldata payload) external;
    function balanceSheet()            external view returns (address);
    function spoke()                   external view returns (address);
    function poolEscrow(uint64 poolId) external view returns (address);
}

interface IBalanceSheetLike {
    function deposit(uint64 poolId, bytes16 scId, address asset, uint256 tokenId, uint128 amount)
        external;
}

interface ISpokeLike {
    function assetToId(address asset, uint256 tokenId) external view returns (uint128);
    function updatePricePoolPerAsset(uint64 poolId, bytes16 scId, uint128 assetId, uint128 poolPerAsset_, uint64 computedAt) external;
    function markersPricePoolPerAsset(uint64 poolId, bytes16 scId, uint128 assetId)
        external
        view
        returns (uint64 computedAt, uint64 maxAge, uint64 validUntil);
    event InitiateTransferShares(
        uint16 centrifugeId,
        uint64 indexed poolId,
        bytes16 indexed scId,
        address indexed sender,
        bytes32 destinationAddress,
        uint128 amount
    );
}

abstract contract CentrifugeTestingBase is CommonTestBase {

    function _testCentrifugeV3RedemptionsOnlyOnboarding(
        address centrifugeVault,
        uint256 redeemMax,
        uint256 redeemSlope
    ) public {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        CentrifugeV3Config memory centrifugeConfig = _prepareCentrifugeConfig(centrifugeVault);

        ICentrifugeV3ShareLike vaultToken = ICentrifugeV3ShareLike(ICentrifugeV3Vault(centrifugeVault).share());

        _prepareCentrifugeWhitelisting(vaultToken, centrifugeConfig.centrifugeRoot);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_7540_DEPOSIT,
            centrifugeVault
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_7540_REDEEM,
            centrifugeVault
        );

        _assertZeroRateLimit(depositKey);
        _assertZeroRateLimit(redeemKey);

        executeAllPayloadsAndBridges();

        // Reload the context after spell execution to get the new controller after potential controller upgrade
        ctx = _getGroveLiquidityLayerContext();

        _assertZeroRateLimit(depositKey);
        _assertRateLimit(redeemKey, redeemMax, redeemSlope);

        IERC20 asset = IERC20(ICentrifugeV3Vault(centrifugeVault).asset());

        uint256 startShareBalance = vaultToken.balanceOf(address(ctx.proxy));

        vm.prank(ctx.admin);
        IRateLimits(ctx.rateLimits).setRateLimitData(depositKey, redeemMax * 2, 0);
        deal(address(asset), address(ctx.proxy), redeemMax * 2);
        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeVault, redeemMax * 2);
        _centrifugeV3FulfillDepositRequest(
            centrifugeConfig,
            redeemMax * 2
        );
        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeVault);
        vm.prank(ctx.admin);
        IRateLimits(ctx.rateLimits).setRateLimitData(depositKey, 0, 0);

        _assertZeroRateLimit(depositKey);
        _assertRateLimit(redeemKey, redeemMax, redeemSlope);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance + redeemMax);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestRedeemERC7540(centrifugeVault, redeemMax);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        _centrifugeV3FulfillRedeemRequest(
            centrifugeConfig,
            redeemMax
        );

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimRedeemERC7540(centrifugeVault);

        assertEq(asset.balanceOf(address(ctx.proxy)),      redeemMax * 2);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);
    }

    function _testCentrifugeV3Onboarding(
        address centrifugeVault,
        uint256 depositMax,
        uint256 depositSlope
    ) public {
        _testCentrifugeV3DepositRateLimitIncrease(centrifugeVault, 0, 0, depositMax, depositSlope);
    }

    function _testCentrifugeV3DepositRateLimitIncrease(
        address centrifugeVault,
        uint256 previousDepositMax,
        uint256 previousDepositSlope,
        uint256 newDepositMax,
        uint256 newDepositSlope
    ) public {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        CentrifugeV3Config memory centrifugeConfig = _prepareCentrifugeConfig(centrifugeVault);

        ICentrifugeV3ShareLike vaultToken = ICentrifugeV3ShareLike(ICentrifugeV3Vault(centrifugeVault).share());

        _prepareCentrifugeWhitelisting(vaultToken, centrifugeConfig.centrifugeRoot);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_7540_DEPOSIT,
            centrifugeVault
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_7540_REDEEM,
            centrifugeVault
        );

        bool isOnboarding = previousDepositMax == 0 && previousDepositSlope == 0;

        _assertRateLimit(depositKey, previousDepositMax, previousDepositSlope);
        if (isOnboarding) {
            _assertZeroRateLimit(redeemKey);
        } else {
            _assertRateLimit(redeemKey, type(uint256).max, 0);
        }

        executeAllPayloadsAndBridges();

        ctx = _getGroveLiquidityLayerContext();

        IERC20 asset = IERC20(ICentrifugeV3Vault(centrifugeVault).asset());

        deal(address(asset), address(ctx.proxy), newDepositMax);

        _assertRateLimit(depositKey, newDepositMax,     newDepositSlope);
        _assertRateLimit(redeemKey,  type(uint256).max, 0);

        uint256 startShareBalance = vaultToken.balanceOf(address(ctx.proxy));

        assertEq(asset.balanceOf(address(ctx.proxy)),      newDepositMax);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), newDepositMax);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeVault, newDepositMax);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), 0);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        _centrifugeV3FulfillDepositRequest(
            centrifugeConfig,
            newDepositMax
        );

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeVault);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance + newDepositMax / 2);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestRedeemERC7540(centrifugeVault, newDepositMax / 2);

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        _centrifugeV3FulfillRedeemRequest(
            centrifugeConfig,
            newDepositMax / 2
        );

        assertEq(asset.balanceOf(address(ctx.proxy)),      0);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimRedeemERC7540(centrifugeVault);

        assertEq(asset.balanceOf(address(ctx.proxy)),      newDepositMax);
        assertEq(vaultToken.balanceOf(address(ctx.proxy)), startShareBalance);
    }

    function _testCentrifugeCrosschainTransferOnboarding(
        address centrifugeVault,
        address destinationAddress,
        uint16  destinationCentrifugeId,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        bytes32 centrifugeCrosschainTransferKey = keccak256(abi.encode(GroveLiquidityLayerHelpers.LIMIT_CENTRIFUGE_TRANSFER, centrifugeVault, destinationCentrifugeId));
        bytes32 castedDestinationAddress = CastingHelpers.addressToCentrifugeRecipient(destinationAddress);
        uint128 expectedTransferAmount = uint128(maxAmount);

        _assertZeroRateLimit(centrifugeCrosschainTransferKey);

        executeAllPayloadsAndBridges();

        _assertRateLimit(centrifugeCrosschainTransferKey, maxAmount, slope);

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        CentrifugeV3Config memory centrifugeConfig = _prepareCentrifugeConfig(centrifugeVault);

        ICentrifugeV3ShareLike vaultToken = ICentrifugeV3ShareLike(ICentrifugeV3Vault(centrifugeConfig.centrifugeVault).share());

        _prepareCentrifugeWhitelisting(vaultToken, centrifugeConfig.centrifugeRoot);

        deal(centrifugeConfig.centrifugeAsset, address(ctx.proxy), expectedTransferAmount * 2);
        deal(ctx.relayer, 1 ether);  // Gas cost for Centrifuge

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).requestDepositERC7540(centrifugeConfig.centrifugeVault, expectedTransferAmount * 2);

        _centrifugeV3FulfillDepositRequest(
            centrifugeConfig,
            expectedTransferAmount * 2
        );

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).claimDepositERC7540(centrifugeConfig.centrifugeVault);

        uint256 proxyBalanceBefore     = vaultToken.balanceOf(address(ctx.proxy));
        uint256 shareTotalSupplyBefore = vaultToken.totalSupply();

        vm.expectEmit(centrifugeConfig.centrifugeSpoke);
        emit ISpokeLike.InitiateTransferShares(
            destinationCentrifugeId,
            centrifugeConfig.centrifugePoolId,
            centrifugeConfig.centrifugeScId,
            address(ctx.proxy),
            castedDestinationAddress,
            expectedTransferAmount
        );

        vm.startPrank(ctx.relayer);
        MainnetController(ctx.controller).transferSharesCentrifuge{value: 1 ether}(
            centrifugeConfig.centrifugeVault,
            expectedTransferAmount,
            destinationCentrifugeId
        );

        uint256 proxyBalanceAfter     = vaultToken.balanceOf(address(ctx.proxy));
        uint256 shareTotalSupplyAfter = vaultToken.totalSupply();

        assertEq(proxyBalanceAfter,     proxyBalanceBefore     - expectedTransferAmount);
        assertEq(shareTotalSupplyAfter, shareTotalSupplyBefore - expectedTransferAmount);
    }

    function _prepareCentrifugeConfig(address centrifugeVault) internal view returns (CentrifugeV3Config memory) {
        IAsyncRedeemManagerLike centrifugeManager = IAsyncRedeemManagerLike(ICentrifugeV3Vault(centrifugeVault).manager());
        ISpokeLike centrifugeSpoke = ISpokeLike(centrifugeManager.spoke());
        address centrifugeAsset = ICentrifugeV3Vault(centrifugeVault).asset();

        return CentrifugeV3Config({
            centrifugeVault   : centrifugeVault,
            centrifugeRoot    : ICentrifugeV3Vault(centrifugeVault).root(),
            centrifugeManager : address(centrifugeManager),
            centrifugeAsset   : centrifugeAsset,
            centrifugeSpoke   : address(centrifugeSpoke),
            centrifugeScId    : ICentrifugeV3Vault(centrifugeVault).scId(),
            centrifugePoolId  : ICentrifugeV3Vault(centrifugeVault).poolId(),
            centrifugeAssetId : centrifugeSpoke.assetToId(centrifugeAsset, 0)
        });
    }

    function _prepareCentrifugeWhitelisting(ICentrifugeV3ShareLike vaultToken, address centrifugeRoot) internal {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        vm.startPrank(centrifugeRoot);
        IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(ctx.proxy), type(uint64).max);
        if (ChainIdUtils.fromUint(block.chainid) == ChainIdUtils.Ethereum()) {
            IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(uint160(GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID)), type(uint64).max);
            IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(uint160(GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID)),     type(uint64).max);
        } else {
            IFreelyTransferableHookLike(vaultToken.hook()).updateMember(address(vaultToken), address(uint160(GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID)), type(uint64).max);
        }
        vm.stopPrank();
    }

    function _centrifugeV3FulfillDepositRequest(
        CentrifugeV3Config memory config,
        uint256 assetAmount
    ) internal {
        uint128 _assetAmount = uint128(assetAmount);

        // ApprovedDeposits callback
        {
            bytes memory payload = abi.encodePacked(
                uint8(RequestCallbackType.ApprovedDeposits),
                _assetAmount,      // approvedAssetAmount
                uint128(1e18)      // pricePoolPerAsset (1:1 for stablecoins)
            );
            vm.prank(config.centrifugeRoot);
            IAsyncRedeemManagerLike(config.centrifugeManager).callback(
                config.centrifugePoolId,
                config.centrifugeScId,
                config.centrifugeAssetId,
                payload
            );
        }

        // IssuedShares callback
        {
            bytes memory payload = abi.encodePacked(
                uint8(RequestCallbackType.IssuedShares),
                _assetAmount / 2,  // shareAmount
                uint128(2e18)      // pricePoolPerShare
            );
            vm.prank(config.centrifugeRoot);
            IAsyncRedeemManagerLike(config.centrifugeManager).callback(
                config.centrifugePoolId,
                config.centrifugeScId,
                config.centrifugeAssetId,
                payload
            );
        }

        // FulfilledDepositRequest callback
        {
            GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();
            bytes memory payload = abi.encodePacked(
                uint8(RequestCallbackType.FulfilledDepositRequest),
                bytes32(bytes20(address(ctx.proxy))),  // investor (LEFT-aligned)
                _assetAmount,                          // fulfilledAssets
                _assetAmount / 2,                      // fulfilledShares
                uint128(0)                             // cancelledAssets
            );
            vm.prank(config.centrifugeRoot);
            IAsyncRedeemManagerLike(config.centrifugeManager).callback(
                config.centrifugePoolId,
                config.centrifugeScId,
                config.centrifugeAssetId,
                payload
            );
        }

    }

    function _centrifugeV3FulfillRedeemRequest(
        CentrifugeV3Config memory config,
        uint256 tokenAmount
    ) internal {
        uint128 _tokenAmount = uint128(tokenAmount);
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        IAsyncRedeemManagerLike manager = IAsyncRedeemManagerLike(config.centrifugeManager);

        // Set initial asset price if not set
        {
            ISpokeLike spoke = ISpokeLike(manager.spoke());
            (uint64 computedAt,,) = spoke.markersPricePoolPerAsset(config.centrifugePoolId, config.centrifugeScId, config.centrifugeAssetId);
            if (computedAt == 0) {
                vm.prank(config.centrifugeRoot);
                spoke.updatePricePoolPerAsset(config.centrifugePoolId, config.centrifugeScId, config.centrifugeAssetId, 1e18, uint64(block.timestamp));
            }
        }

        // RevokedShares callback
        vm.prank(config.centrifugeRoot);
        manager.callback(
            config.centrifugePoolId,
            config.centrifugeScId,
            config.centrifugeAssetId,
            abi.encodePacked(
                uint8(RequestCallbackType.RevokedShares),
                _tokenAmount * 2,  // assetAmount
                _tokenAmount,      // shareAmount
                uint128(2e18)      // pricePoolPerShare
            )
        );

        // Deposit assets so that user can claim USDC via vault afterwards
        {
            address balanceSheet = manager.balanceSheet();
            address asset = ICentrifugeV3Vault(config.centrifugeVault).asset();

            deal2(asset, config.centrifugeManager, _tokenAmount * 2);
            vm.prank(config.centrifugeManager);
            IERC20(asset).approve(balanceSheet, _tokenAmount * 2);
            vm.prank(config.centrifugeManager);
            IBalanceSheetLike(balanceSheet).deposit(
                config.centrifugePoolId,
                config.centrifugeScId,
                asset,
                0,
                _tokenAmount * 2
            );
        }

        // FulfilledRedeemRequest callback
        vm.prank(config.centrifugeRoot);
        manager.callback(
            config.centrifugePoolId,
            config.centrifugeScId,
            config.centrifugeAssetId,
            abi.encodePacked(
                uint8(RequestCallbackType.FulfilledRedeemRequest),
                bytes32(bytes20(address(ctx.proxy))),  // investor (LEFT-aligned)
                _tokenAmount * 2,                      // fulfilledAssets
                _tokenAmount,                          // fulfilledShares
                uint128(0)                             // cancelledShares
            )
        );
    }

}
