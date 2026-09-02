// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260910_Test is GroveTestBase {

    address internal constant PAYLOAD_ETHEREUM = 0x73F9798B24b7843B8028f905373124EfCAF25Da4;

    // Must equal the address hardcoded in the 20260910 payload.
    address internal constant GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT = 0xbeef05061FE51eA482BD1b68041353490b3a5934;

    address internal constant USDG = 0xe343167631d89B6Ffc58B88d6b7fB0228795491D;

    constructor() {
        id = "20260910";
    }

    function setUp() public {
        setupDomains("2026-09-02T13:15:47Z");

        chainData[ChainIdUtils.Ethereum()].payload = PAYLOAD_ETHEREUM;
    }

    function test_ETHEREUM_onboardGroveXSteakhouseUsdgMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        assertEq(IERC4626(GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT).asset(),  USDG, "vault-asset-is-not-usdg");
        assertEq(IERC20(USDG).decimals(),                                    6,    "usdg-decimals-not-6");
        assertEq(IERC20(GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT).decimals(), 18,   "vault-share-decimals-not-18");

        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_USDG_V2_MORPHO_VAULT,
            expectedDepositAmount : 50_000_000e6,
            depositMax            : 50_000_000e6,
            depositSlope          : 50_000_000e6 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 2e6
        });
    }

}
