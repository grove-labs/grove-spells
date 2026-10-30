// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Base }     from "lib/grove-address-registry/src/Base.sol";
import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { RateLimitHelpers } from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface IVaultV2Like {
    function curator() external view returns (address);
    function isSentinel(address account) external view returns (bool);
    function owner() external view returns (address);
}

contract GroveEthereum_20261105_Test is GroveTestBase {

    address internal constant PAYLOAD_ETHEREUM = 0xb7fdd2f1efE69EC2145A914bCEB23D48de4Bb74D;
    address internal constant PAYLOAD_BASE     = 0x5dA864316D7D5E04520605953f2002bdf2e94F40;

    address internal constant VAULT_CURATOR  = 0x622E19d6903BD4507cfc70b31d5B99535114C0FC;
    address internal constant VAULT_SENTINEL = 0xB597026150552bB3F6092aC685A2241C5FA77Ed0;

    constructor() {
        id = "20261105";
    }

    function setUp() public {
        setupDomains("2026-10-27T13:04:59Z");

        chainData[ChainIdUtils.Ethereum()].payload = PAYLOAD_ETHEREUM;
        chainData[ChainIdUtils.Base()].payload     = PAYLOAD_BASE;
    }

    function test_BASE_raiseGroveXSteakhouseUsdcV2MorphoVaultDepositRateLimit()
        public
        onChain(ChainIdUtils.Base())
    {
        IVaultV2Like vault = IVaultV2Like(Base.GROVE_X_STEAKHOUSE_USDC_V2_MORPHO_VAULT);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            address(vault)
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_WITHDRAW,
            address(vault)
        );

        assertEq(vault.owner(), Base.GROVE_EXECUTOR, "base-vault-owner-mismatch");
        assertEq(vault.curator(), VAULT_CURATOR, "base-vault-curator-mismatch");
        assertTrue(vault.isSentinel(VAULT_SENTINEL), "base-vault-sentinel-mismatch");
        assertEq(
            depositKey,
            0x75df43c10c790bf60cc8db589d93ba979a8711aab94a828290155f0f9cb7e6ac,
            "base-deposit-key-mismatch"
        );
        _assertRateLimit(depositKey, 20_000_000e6, 20_000_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, 100_000_000e6, 100_000_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);
    }

    function test_ETHEREUM_raiseGroveXSteakhouseUsdcV2MorphoVaultDepositRateLimit()
        public
        onChain(ChainIdUtils.Ethereum())
    {
        IVaultV2Like vault = IVaultV2Like(Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            address(vault)
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            GroveLiquidityLayerHelpers.LIMIT_4626_WITHDRAW,
            address(vault)
        );

        assertEq(vault.owner(), Ethereum.GROVE_PROXY, "ethereum-vault-owner-mismatch");
        assertEq(vault.curator(), VAULT_CURATOR, "ethereum-vault-curator-mismatch");
        assertTrue(vault.isSentinel(VAULT_SENTINEL), "ethereum-vault-sentinel-mismatch");
        assertEq(
            depositKey,
            0xe9ff67ad8829919752eee93c75433e7e23f3460ca6b1d9576fae94f669fbc4d6,
            "ethereum-deposit-key-mismatch"
        );
        _assertRateLimit(depositKey, 20_000_000e6, 20_000_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, 100_000_000e6, 100_000_000e6 / uint256(1 days));
        _assertRateLimit(withdrawKey, type(uint256).max, 0);
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
