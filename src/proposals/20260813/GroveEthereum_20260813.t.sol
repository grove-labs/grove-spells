// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IALMProxy } from "lib/grove-alm-controller/src/interfaces/IALMProxy.sol";

import { makeAddressKey, makeAddressAddressKey } from "diamond-pau/libraries/RateLimitHelpers.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

import { GroveLiquidityLayerContext } from "src/test-harness/CommonALMTestBase.sol";

import { IPauBaseControllerLike, PauContext } from "src/test-harness/CommonPauTestBase.sol";

// Struct return, ABI-identical to the manager's 12-value tuple: decoding into locals overflows the stack without viaIR.
interface IPositionManagerLike {
    struct Position {
        uint96  nonce;
        address operator;
        address token0;
        address token1;
        uint24  fee;
        int24   tickLower;
        int24   tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function positions(uint256 tokenId) external view returns (Position memory position);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);
}

interface IUniswapV3PoolLike {
    function observe(uint32[] calldata secondsAgos)
        external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
}

interface IPauControllerLike is IPauBaseControllerLike {
    struct Ticks {
        int24 lower;
        int24 upper;
    }

    struct TokenAmounts {
        uint256 amount0;
        uint256 amount1;
    }

    function uniswapV3_VERSION() external pure returns (string memory);
    function uniswapV3_MAX_TICK_DELTA() external pure returns (uint24);
    function uniswapV3_MIN_TICK() external pure returns (int24);
    function uniswapV3_MAX_TICK() external pure returns (int24);
    function uniswapV3_positionManager() external view returns (address);
    function uniswapV3_router() external view returns (address);
    function uniswapV3_setLiquidityLowerTickBound(address pool, int24 lowerTickBound) external;
    function uniswapV3_setLiquidityUpperTickBound(address pool, int24 upperTickBound) external;
    function uniswapV3_setMaxSlippage(address pool, uint256 maxSlippage) external;
    function uniswapV3_setMaxTickDelta(address pool, uint24 maxTickDelta) external;
    function uniswapV3_setTWAPSecondsAgo(address pool, uint32 twapSecondsAgo) external;
    function uniswapV3_swap(address pool, address tokenIn, uint256 amountIn, uint256 minAmountOut, uint24 tickDelta)
        external returns (uint256 amountOut);
    function uniswapV3_getAggregateDepositRateLimitKey(address pool) external view returns (bytes32);
    function uniswapV3_getAggregateWithdrawRateLimitKey(address pool) external view returns (bytes32);
    function uniswapV3_getAssetDepositRateLimitKey(address pool, address token) external view returns (bytes32);
    function uniswapV3_getAssetWithdrawRateLimitKey(address pool, address token) external view returns (bytes32);
    function uniswapV3_getSwapRateLimitKey(address pool, address token) external view returns (bytes32);
    function uniswapV3_getLiquidityTickBounds(address pool) external view returns (int24 lower, int24 upper);
    function uniswapV3_getMaxSlippage(address pool) external view returns (uint256);
    function uniswapV3_getMaxTickDelta(address pool) external view returns (uint24);
    function uniswapV3_getTWAPSecondsAgo(address pool) external view returns (uint32);
    function uniswapV3_addLiquidity(
        address pool,
        uint256 tokenId,
        Ticks calldata ticks,
        TokenAmounts calldata target,
        TokenAmounts calldata min,
        uint256 deadline
    ) external returns (uint256 tokenId_, uint128 liquidity, TokenAmounts memory amounts);
    function uniswapV3_removeLiquidity(
        address pool,
        uint256 tokenId,
        uint128 liquidity,
        TokenAmounts calldata min,
        uint256 deadline
    ) external returns (TokenAmounts memory amounts);
}

contract GroveEthereum_20260813_Test is GroveTestBase {

    // UNISWAP_V3_FACET in the Sky-governed PAU Beacon.
    address internal constant PAU_UNISWAP_V3_FACET = 0x445D9Dc752F269Be48250f1A180CAC4c61cE4bab;

    bytes32 internal constant LIMIT_UNISWAP_V3_DEPOSIT  = keccak256("LIMIT_UNISWAP_V3_DEPOSIT");
    bytes32 internal constant LIMIT_UNISWAP_V3_SWAP     = keccak256("LIMIT_UNISWAP_V3_SWAP");
    bytes32 internal constant LIMIT_UNISWAP_V3_WITHDRAW = keccak256("LIMIT_UNISWAP_V3_WITHDRAW");

    uint256 internal constant AGGREGATE_DEPOSIT_MAX   = 5_000_000e18;
    uint256 internal constant AGGREGATE_DEPOSIT_SLOPE = 0;
    uint256 internal constant ASSET_DEPOSIT_MAX       = 5_000_000e6;
    uint256 internal constant ASSET_DEPOSIT_SLOPE     = 0;
    uint256 internal constant SWAP_MAX                = 1_000_000e6;
    uint256 internal constant SWAP_SLOPE              = 5_000_000e6 / uint256(1 days);

    // Must equal the tokenId hardcoded in the 20260813 payload.
    uint256 internal constant UNISWAP_V3_POSITION_TOKEN_ID = 1192575;

    constructor() {
        id = "20260813";
    }

    function setUp() public {
        setupDomains("2026-07-29T10:13:44Z");

        deployPayloads();
    }

    function test_ETHEREUM_enableUniswapV3Facet() public onChain(ChainIdUtils.Ethereum()) {
        IPauControllerLike controller = IPauControllerLike(Ethereum.PAU_CONTROLLER);

        bytes32 aggregateDepositKey  = makeAddressKey(LIMIT_UNISWAP_V3_DEPOSIT,  Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 aggregateWithdrawKey = makeAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.UNISWAP_V3_AUSD_USDC);

        bytes32 ausdDepositKey  = makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT,  Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcDepositKey  = makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT,  Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 ausdWithdrawKey = makeAddressAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcWithdrawKey = makeAddressAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 ausdSwapKey     = makeAddressAddressKey(LIMIT_UNISWAP_V3_SWAP,     Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcSwapKey     = makeAddressAddressKey(LIMIT_UNISWAP_V3_SWAP,     Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);

        // --- Before: facet not wired, none of the eight keys set. ---
        assertEq(
            controller.getDispatch(IPauControllerLike.uniswapV3_VERSION.selector).facet,
            address(0),
            "uniswap-v3-facet-already-wired"
        );

        _assertPauZeroRateLimit(aggregateDepositKey);
        _assertPauZeroRateLimit(aggregateWithdrawKey);
        _assertPauZeroRateLimit(ausdDepositKey);
        _assertPauZeroRateLimit(usdcDepositKey);
        _assertPauZeroRateLimit(ausdWithdrawKey);
        _assertPauZeroRateLimit(usdcWithdrawKey);
        _assertPauZeroRateLimit(ausdSwapKey);
        _assertPauZeroRateLimit(usdcSwapKey);

        executeAllPayloadsAndBridges();

        // --- After: all 23 facet selectors dispatched to the Beacon's UniswapV3 facet. ---
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_VERSION.selector).facet,        PAU_UNISWAP_V3_FACET, "uniswap-v3-version-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_MAX_TICK_DELTA.selector).facet, PAU_UNISWAP_V3_FACET, "uniswap-v3-max-tick-delta-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_MIN_TICK.selector).facet,       PAU_UNISWAP_V3_FACET, "uniswap-v3-min-tick-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_MAX_TICK.selector).facet,       PAU_UNISWAP_V3_FACET, "uniswap-v3-max-tick-not-wired");

        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_positionManager.selector).facet, PAU_UNISWAP_V3_FACET, "uniswap-v3-position-manager-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_router.selector).facet,          PAU_UNISWAP_V3_FACET, "uniswap-v3-router-not-wired");

        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_setLiquidityLowerTickBound.selector).facet, PAU_UNISWAP_V3_FACET, "uniswap-v3-set-lower-tick-bound-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_setLiquidityUpperTickBound.selector).facet, PAU_UNISWAP_V3_FACET, "uniswap-v3-set-upper-tick-bound-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_setMaxSlippage.selector).facet,             PAU_UNISWAP_V3_FACET, "uniswap-v3-set-max-slippage-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_setMaxTickDelta.selector).facet,            PAU_UNISWAP_V3_FACET, "uniswap-v3-set-max-tick-delta-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_setTWAPSecondsAgo.selector).facet,          PAU_UNISWAP_V3_FACET, "uniswap-v3-set-twap-seconds-ago-not-wired");

        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_swap.selector).facet,            PAU_UNISWAP_V3_FACET, "uniswap-v3-swap-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_addLiquidity.selector).facet,    PAU_UNISWAP_V3_FACET, "uniswap-v3-add-liquidity-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_removeLiquidity.selector).facet, PAU_UNISWAP_V3_FACET, "uniswap-v3-remove-liquidity-not-wired");

        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getAggregateDepositRateLimitKey.selector).facet,  PAU_UNISWAP_V3_FACET, "uniswap-v3-aggregate-deposit-key-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getAggregateWithdrawRateLimitKey.selector).facet, PAU_UNISWAP_V3_FACET, "uniswap-v3-aggregate-withdraw-key-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getAssetDepositRateLimitKey.selector).facet,      PAU_UNISWAP_V3_FACET, "uniswap-v3-asset-deposit-key-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getAssetWithdrawRateLimitKey.selector).facet,     PAU_UNISWAP_V3_FACET, "uniswap-v3-asset-withdraw-key-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getSwapRateLimitKey.selector).facet,              PAU_UNISWAP_V3_FACET, "uniswap-v3-swap-key-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getLiquidityTickBounds.selector).facet,           PAU_UNISWAP_V3_FACET, "uniswap-v3-tick-bounds-getter-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getMaxSlippage.selector).facet,                   PAU_UNISWAP_V3_FACET, "uniswap-v3-max-slippage-getter-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getMaxTickDelta.selector).facet,                  PAU_UNISWAP_V3_FACET, "uniswap-v3-max-tick-delta-getter-not-wired");
        assertEq(controller.getDispatch(IPauControllerLike.uniswapV3_getTWAPSecondsAgo.selector).facet,                PAU_UNISWAP_V3_FACET, "uniswap-v3-twap-getter-not-wired");

        // The facet's own getters must agree with the keys the payload wrote.
        assertEq(controller.uniswapV3_getAggregateDepositRateLimitKey(Ethereum.UNISWAP_V3_AUSD_USDC),  aggregateDepositKey,  "aggregate-deposit-key-mismatch");
        assertEq(controller.uniswapV3_getAggregateWithdrawRateLimitKey(Ethereum.UNISWAP_V3_AUSD_USDC), aggregateWithdrawKey, "aggregate-withdraw-key-mismatch");

        assertEq(controller.uniswapV3_getAssetDepositRateLimitKey(Ethereum.UNISWAP_V3_AUSD_USDC,  Ethereum.AUSD), ausdDepositKey,  "ausd-deposit-key-mismatch");
        assertEq(controller.uniswapV3_getAssetDepositRateLimitKey(Ethereum.UNISWAP_V3_AUSD_USDC,  Ethereum.USDC), usdcDepositKey,  "usdc-deposit-key-mismatch");
        assertEq(controller.uniswapV3_getAssetWithdrawRateLimitKey(Ethereum.UNISWAP_V3_AUSD_USDC, Ethereum.AUSD), ausdWithdrawKey, "ausd-withdraw-key-mismatch");
        assertEq(controller.uniswapV3_getAssetWithdrawRateLimitKey(Ethereum.UNISWAP_V3_AUSD_USDC, Ethereum.USDC), usdcWithdrawKey, "usdc-withdraw-key-mismatch");

        assertEq(controller.uniswapV3_getSwapRateLimitKey(Ethereum.UNISWAP_V3_AUSD_USDC, Ethereum.AUSD), ausdSwapKey, "ausd-swap-key-mismatch");
        assertEq(controller.uniswapV3_getSwapRateLimitKey(Ethereum.UNISWAP_V3_AUSD_USDC, Ethereum.USDC), usdcSwapKey, "usdc-swap-key-mismatch");

        _assertPauRateLimit(aggregateDepositKey, AGGREGATE_DEPOSIT_MAX, AGGREGATE_DEPOSIT_SLOPE);
        _assertPauRateLimit(ausdDepositKey,      ASSET_DEPOSIT_MAX,     ASSET_DEPOSIT_SLOPE);
        _assertPauRateLimit(usdcDepositKey,      ASSET_DEPOSIT_MAX,     ASSET_DEPOSIT_SLOPE);

        _assertPauUnlimitedRateLimit(aggregateWithdrawKey);
        _assertPauUnlimitedRateLimit(ausdWithdrawKey);
        _assertPauUnlimitedRateLimit(usdcWithdrawKey);

        _assertPauRateLimit(ausdSwapKey, SWAP_MAX, SWAP_SLOPE);
        _assertPauRateLimit(usdcSwapKey, SWAP_MAX, SWAP_SLOPE);
    }

    function test_ETHEREUM_uniswapV3FacetPoolParams() public onChain(ChainIdUtils.Ethereum()) {
        IPauControllerLike controller = IPauControllerLike(Ethereum.PAU_CONTROLLER);

        executeAllPayloadsAndBridges();

        // The params mirror the live ALM-side config (January 29, 2026 onboarding).
        ( int24 lowerTickBound, int24 upperTickBound ) =
            controller.uniswapV3_getLiquidityTickBounds(Ethereum.UNISWAP_V3_AUSD_USDC);

        assertEq(controller.uniswapV3_getMaxSlippage(Ethereum.UNISWAP_V3_AUSD_USDC),    0.999e18, "max-slippage-mismatch");
        assertEq(controller.uniswapV3_getMaxTickDelta(Ethereum.UNISWAP_V3_AUSD_USDC),   200,      "max-tick-delta-mismatch");
        assertEq(controller.uniswapV3_getTWAPSecondsAgo(Ethereum.UNISWAP_V3_AUSD_USDC), 600,      "twap-seconds-ago-mismatch");

        assertEq(lowerTickBound, -10, "lower-tick-bound-mismatch");
        assertEq(upperTickBound, 10,  "upper-tick-bound-mismatch");
    }

    function test_ETHEREUM_uniswapV3FacetAddRemoveLiquidity() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        PauContext memory ctx = _getPauContext();

        uint256 depositAmount = 1_000_000e6;

        deal(Ethereum.USDC, address(ctx.proxy), depositAmount);

        bytes32 aggregateDepositKey = makeAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 ausdDepositKey      = makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcDepositKey      = makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);

        // A single-sided USDC range strictly below the TWAP tick makes the expected amounts price-independent.
        int24 tickUpper = _twapTick(Ethereum.UNISWAP_V3_AUSD_USDC, 600) - 1;
        if (tickUpper > 10) tickUpper = 10;
        assertGt(tickUpper, -10, "twap-tick-outside-liquidity-bounds");

        bytes memory result = _callAsPauActor(ctx, abi.encodeCall(
            IPauControllerLike.uniswapV3_addLiquidity,
            (
                Ethereum.UNISWAP_V3_AUSD_USDC,
                0,
                IPauControllerLike.Ticks({ lower: -10, upper: tickUpper }),
                IPauControllerLike.TokenAmounts({ amount0: 0, amount1: depositAmount }),
                IPauControllerLike.TokenAmounts({ amount0: 0, amount1: depositAmount * 999 / 1000 }),
                block.timestamp + 1 hours
            )
        ));

        ( uint256 tokenId, uint128 liquidity, IPauControllerLike.TokenAmounts memory deposited ) =
            abi.decode(result, (uint256, uint128, IPauControllerLike.TokenAmounts));

        assertGt(liquidity, 0, "no-liquidity-minted");

        assertEq(deposited.amount0, 0,                            "ausd-unexpectedly-deposited");
        assertGe(deposited.amount1, depositAmount * 999 / 1000,   "usdc-deposited-below-min");

        assertEq(IPositionManagerLike(Ethereum.UNISWAP_V3_POSITION_MANAGER).ownerOf(tokenId), address(ctx.proxy), "position-not-owned-by-pau-proxy");

        assertEq(ctx.rateLimits.getCurrentRateLimit(aggregateDepositKey), AGGREGATE_DEPOSIT_MAX - deposited.amount1 * 1e12, "aggregate-deposit-limit-not-consumed");
        assertEq(ctx.rateLimits.getCurrentRateLimit(usdcDepositKey),      ASSET_DEPOSIT_MAX - deposited.amount1,            "usdc-deposit-limit-not-consumed");
        assertEq(ctx.rateLimits.getCurrentRateLimit(ausdDepositKey),      ASSET_DEPOSIT_MAX,                                "ausd-deposit-limit-consumed");

        // Unwind the whole position: withdrawals are unlimited so the limit stays untouched.
        uint256 proxyUsdcBalance = IERC20(Ethereum.USDC).balanceOf(address(ctx.proxy));

        result = _callAsPauActor(ctx, abi.encodeCall(
            IPauControllerLike.uniswapV3_removeLiquidity,
            (
                Ethereum.UNISWAP_V3_AUSD_USDC,
                tokenId,
                liquidity,
                IPauControllerLike.TokenAmounts({ amount0: 0, amount1: deposited.amount1 * 999 / 1000 }),
                block.timestamp + 1 hours
            )
        ));

        IPauControllerLike.TokenAmounts memory withdrawn = abi.decode(result, (IPauControllerLike.TokenAmounts));

        assertGe(withdrawn.amount1, deposited.amount1 * 999 / 1000, "usdc-not-returned");

        assertEq(IERC20(Ethereum.USDC).balanceOf(address(ctx.proxy)), proxyUsdcBalance + withdrawn.amount1, "proxy-usdc-balance-mismatch");

        assertEq(
            ctx.rateLimits.getCurrentRateLimit(makeAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.UNISWAP_V3_AUSD_USDC)),
            type(uint256).max,
            "aggregate-withdraw-limit-not-unlimited"
        );
    }

    function test_ETHEREUM_uniswapV3FacetSwap() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        PauContext memory ctx = _getPauContext();

        uint256 amountIn = 100_000e6;

        deal(Ethereum.USDC, address(ctx.proxy), amountIn);

        bytes32 ausdSwapKey = makeAddressAddressKey(LIMIT_UNISWAP_V3_SWAP, Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcSwapKey = makeAddressAddressKey(LIMIT_UNISWAP_V3_SWAP, Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);

        uint256 proxyAusdBalance = IERC20(Ethereum.AUSD).balanceOf(address(ctx.proxy));

        // 0.2% tolerance covers the pool's 0.01% fee plus a near-peg price; tick delta at the configured max.
        bytes memory result = _callAsPauActor(ctx, abi.encodeCall(
            IPauControllerLike.uniswapV3_swap,
            (Ethereum.UNISWAP_V3_AUSD_USDC, Ethereum.USDC, amountIn, amountIn * 998 / 1000, 200)
        ));

        uint256 amountOut = abi.decode(result, (uint256));

        assertGe(amountOut, amountIn * 998 / 1000, "swap-amount-out-below-min");

        assertEq(IERC20(Ethereum.AUSD).balanceOf(address(ctx.proxy)), proxyAusdBalance + amountOut, "proxy-ausd-balance-mismatch");
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(ctx.proxy)), 0,                            "usdc-not-fully-spent");

        assertEq(ctx.rateLimits.getCurrentRateLimit(usdcSwapKey), SWAP_MAX - amountIn, "usdc-swap-limit-not-consumed");
        assertEq(ctx.rateLimits.getCurrentRateLimit(ausdSwapKey), SWAP_MAX,            "ausd-swap-limit-consumed");
    }

    function test_ETHEREUM_collectUniswapV3PositionFees() public onChain(ChainIdUtils.Ethereum()) {
        IPositionManagerLike positionManager = IPositionManagerLike(Ethereum.UNISWAP_V3_POSITION_MANAGER);

        IALMProxy almProxy = IALMProxy(Ethereum.ALM_PROXY);
        IERC20    ausd     = IERC20(Ethereum.AUSD);
        IERC20    usdc     = IERC20(Ethereum.USDC);

        bytes32 controllerRole = almProxy.CONTROLLER();

        IPositionManagerLike.Position memory position = positionManager.positions(UNISWAP_V3_POSITION_TOKEN_ID);

        assertEq(position.token0, Ethereum.AUSD, "position-token0-not-ausd");
        assertEq(position.token1, Ethereum.USDC, "position-token1-not-usdc");

        // The tokenId in the payload is the ALM Proxy's one and only position NFT.
        assertEq(positionManager.balanceOf(Ethereum.ALM_PROXY),               1,                             "alm-proxy-position-count-not-one");
        assertEq(positionManager.tokenOfOwnerByIndex(Ethereum.ALM_PROXY, 0),  UNISWAP_V3_POSITION_TOKEN_ID,  "alm-proxy-position-token-id-mismatch");

        assertEq(positionManager.ownerOf(UNISWAP_V3_POSITION_TOKEN_ID), Ethereum.ALM_PROXY, "position-not-owned-by-alm-proxy");

        assertEq(almProxy.hasRole(controllerRole, Ethereum.GROVE_PROXY), false);

        uint256 ausdBalance = ausd.balanceOf(Ethereum.ALM_PROXY);
        uint256 usdcBalance = usdc.balanceOf(Ethereum.ALM_PROXY);

        // The spec pins no amounts, so the balance assertions are bounds rather than exact values.
        executeAllPayloadsAndBridges();

        assertGe(ausd.balanceOf(Ethereum.ALM_PROXY), ausdBalance, "alm-proxy-ausd-balance-decreased");
        assertGe(usdc.balanceOf(Ethereum.ALM_PROXY), usdcBalance, "alm-proxy-usdc-balance-decreased");

        assertGt(
            ausd.balanceOf(Ethereum.ALM_PROXY) + usdc.balanceOf(Ethereum.ALM_PROXY),
            ausdBalance + usdcBalance,
            "no-fees-collected"
        );

        // Only owed fees move: the position keeps its liquidity and its owner.
        IPositionManagerLike.Position memory positionAfter = positionManager.positions(UNISWAP_V3_POSITION_TOKEN_ID);

        assertEq(positionAfter.liquidity,   position.liquidity, "position-liquidity-changed");
        assertEq(positionAfter.tokensOwed0, 0,                  "token0-fees-not-fully-collected");
        assertEq(positionAfter.tokensOwed1, 0,                  "token1-fees-not-fully-collected");

        assertEq(positionManager.ownerOf(UNISWAP_V3_POSITION_TOKEN_ID), Ethereum.ALM_PROXY, "position-owner-changed");

        assertEq(almProxy.hasRole(controllerRole, Ethereum.GROVE_PROXY), false);
    }

    function test_ETHEREUM_almUniswapV3RateLimitsUnchanged() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(_getGroveLiquidityLayerContext().controller);

        bytes32 ausdDepositKey  = RateLimitHelpers.makeAssetDestinationKey(controller.LIMIT_UNISWAP_V3_DEPOSIT(),  Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcDepositKey  = RateLimitHelpers.makeAssetDestinationKey(controller.LIMIT_UNISWAP_V3_DEPOSIT(),  Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 ausdWithdrawKey = RateLimitHelpers.makeAssetDestinationKey(controller.LIMIT_UNISWAP_V3_WITHDRAW(), Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC);
        bytes32 usdcWithdrawKey = RateLimitHelpers.makeAssetDestinationKey(controller.LIMIT_UNISWAP_V3_WITHDRAW(), Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC);

        // --- Before: live limits from the January 29, 2026 onboarding. ---
        _assertRateLimit(ausdDepositKey, 25_000_000e6, 25_000_000e6 / uint256(1 days));
        _assertRateLimit(usdcDepositKey, 25_000_000e6, 25_000_000e6 / uint256(1 days));

        _assertUnlimitedRateLimit(ausdWithdrawKey);
        _assertUnlimitedRateLimit(usdcWithdrawKey);

        executeAllPayloadsAndBridges();

        // --- After: the ALM-side limits come out untouched (additive capacity, not a migration). ---
        _assertRateLimit(ausdDepositKey, 25_000_000e6, 25_000_000e6 / uint256(1 days));
        _assertRateLimit(usdcDepositKey, 25_000_000e6, 25_000_000e6 / uint256(1 days));

        _assertUnlimitedRateLimit(ausdWithdrawKey);
        _assertUnlimitedRateLimit(usdcWithdrawKey);
    }

    function test_ETHEREUM_offboardMapleSyrupUsdcDepositRateLimit() public onChain(ChainIdUtils.Ethereum()) {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        bytes32 depositKey  = RateLimitHelpers.makeAssetKey(MainnetController(ctx.controller).LIMIT_4626_DEPOSIT(),  Ethereum.MAPLE_SYRUP_USDC);
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(MainnetController(ctx.controller).LIMIT_4626_WITHDRAW(), Ethereum.MAPLE_SYRUP_USDC);

        // Key published in the spec, recomputed here from the live controller.
        assertEq(depositKey, 0x99a69e57b2f387f999d6adff6eb2e707b59fdb54f06ca6211b4f20956e9bfe10, "syrup-usdc-deposit-key-mismatch");

        // --- Before: deposits still capped at the onboarded 50M limit, withdrawals never set. ---
        _assertRateLimit(depositKey, 50_000_000e6, 50_000_000e6 / uint256(1 days));
        _assertZeroRateLimit(withdrawKey);

        executeAllPayloadsAndBridges();

        // --- After: the integration is inert in both directions. ---
        _assertZeroRateLimit(depositKey);
        _assertZeroRateLimit(withdrawKey);

        vm.prank(ctx.relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        MainnetController(ctx.controller).depositERC4626(Ethereum.MAPLE_SYRUP_USDC, 1e6);
    }

    function _twapTick(address pool, uint32 secondsAgo) internal view returns (int24) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        ( int56[] memory tickCumulatives, ) = IUniswapV3PoolLike(pool).observe(secondsAgos);

        return int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(secondsAgo)));
    }

}
