// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IALMProxy }       from "lib/grove-alm-controller/src/interfaces/IALMProxy.sol";
import { RateLimitHelpers } from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20261105_Test is GroveTestBase {

    address internal constant GROVE_FOUNDATION = 0xE3EC4CC359E68c9dCE15Bf667b1aD37Df54a5a42;

    constructor() {
        id = "20261105";
    }

    function setUp() public {
        setupDomains("2026-10-20T09:54:54Z");
        deployPayloads();
    }

    function test_AVALANCHE_transferAvaxToGroveFoundation() public onChain(ChainIdUtils.Avalanche()) {
        IALMProxy almProxy      = IALMProxy(Avalanche.ALM_PROXY);
        bytes32   controllerRole = almProxy.CONTROLLER();

        uint256 proxyBalanceBefore      = Avalanche.ALM_PROXY.balance;
        uint256 foundationBalanceBefore = GROVE_FOUNDATION.balance;

        assertEq(proxyBalanceBefore, 480_481.63e18, "alm-proxy-avax-balance-mismatch");
        assertFalse(
            almProxy.hasRole(controllerRole, Avalanche.GROVE_EXECUTOR),
            "executor-has-controller-role-before"
        );
        assertTrue(
            almProxy.hasRole(controllerRole, Avalanche.ALM_CONTROLLER),
            "alm-controller-missing-role-before"
        );

        executeAllPayloadsAndBridges();

        assertEq(Avalanche.ALM_PROXY.balance, 0, "alm-proxy-avax-not-transferred");
        assertEq(
            GROVE_FOUNDATION.balance,
            foundationBalanceBefore + 480_481.63e18,
            "foundation-avax-balance-not-increased"
        );
        assertFalse(
            almProxy.hasRole(controllerRole, Avalanche.GROVE_EXECUTOR),
            "executor-controller-role-not-revoked"
        );
        assertTrue(
            almProxy.hasRole(controllerRole, Avalanche.ALM_CONTROLLER),
            "alm-controller-role-changed"
        );
    }

    function test_BASE_raiseGroveXSteakhouseUsdcV2MorphoVaultDepositRateLimit()
        public
        onChain(ChainIdUtils.Base())
    {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            Base.GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT
        );

        assertEq(
            depositKey,
            0x75df43c10c790bf60cc8db589d93ba979a8711aab94a828290155f0f9cb7e6ac,
            "base-deposit-key-mismatch"
        );
        _assertRateLimit(depositKey, 20_000_000e6, 20_000_000e6 / uint256(1 days));

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, 100_000_000e6, 100_000_000e6 / uint256(1 days));
    }

    function test_ETHEREUM_raiseGroveXSteakhouseUsdcV2MorphoVaultDepositRateLimit()
        public
        onChain(ChainIdUtils.Ethereum())
    {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT
        );

        assertEq(
            depositKey,
            0xe9ff67ad8829919752eee93c75433e7e23f3460ca6b1d9576fae94f669fbc4d6,
            "ethereum-deposit-key-mismatch"
        );
        _assertRateLimit(depositKey, 20_000_000e6, 20_000_000e6 / uint256(1 days));

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, 100_000_000e6, 100_000_000e6 / uint256(1 days));
    }

    function test_ETHEREUM_swapUsdcToUsdsViaPsm() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usdc = IERC20(Ethereum.USDC);
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 usdcBalanceBefore = usdc.balanceOf(Ethereum.GROVE_PROXY);
        uint256 usdsBalanceBefore = usds.balanceOf(Ethereum.GROVE_PROXY);

        assertEq(usdcBalanceBefore, 1_484_740_589999, "grove-proxy-usdc-balance-mismatch");
        assertEq(
            usdc.allowance(Ethereum.GROVE_PROXY, Ethereum.WRAPPER_USDS_LITE_PSM_USDC_A),
            0,
            "wrapper-usdc-allowance-not-zero-before"
        );

        executeAllPayloadsAndBridges();

        assertEq(usdc.balanceOf(Ethereum.GROVE_PROXY), 0, "grove-proxy-usdc-not-fully-spent");
        assertEq(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            usdsBalanceBefore + 1_484_740_589999 * 1e12,
            "grove-proxy-usds-balance-not-increased"
        );
        assertEq(
            usdc.allowance(Ethereum.GROVE_PROXY, Ethereum.WRAPPER_USDS_LITE_PSM_USDC_A),
            0,
            "wrapper-usdc-allowance-not-reset"
        );
    }

}
