// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260507_Test is GroveTestBase {

    address internal constant ETHEREUM_PAYLOAD = 0x8EF80aBDa108a23eA01C8A3D1F5C8B49DD2008e8;

    address internal constant GROVE_X_STEAKHOUSE_RLUSD_V2 = 0xBeEff4fD39F8e48b6a6e475445D650cb11e9599F;

    address internal constant GROVE_FOUNDATION = 0xE3EC4CC359E68c9dCE15Bf667b1aD37Df54a5a42;

    uint256 internal constant GROVE_FOUNDATION_GRANT_AMOUNT = 800_000e18;

    constructor() {
        id = "20260507";
    }

    function setUp() public {
        setupDomains("2026-04-30T16:18:00Z");

        chainData[ChainIdUtils.Ethereum()].payload = ETHEREUM_PAYLOAD;
    }

    function test_ETHEREUM_onboardGroveXSteakhouseRlusdMorphoVaultV2() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_RLUSD_V2,
            expectedDepositAmount : 100_000_000e18,
            depositMax            : 100_000_000e18,
            depositSlope          : 100_000_000e18 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 3e18
        });
    }

    function test_ETHEREUM_transferMonthlyGrantToGroveFoundation() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 foundationBalanceBefore = usds.balanceOf(GROVE_FOUNDATION);
        uint256 groveProxyBalanceBefore = usds.balanceOf(Ethereum.GROVE_PROXY);

        assertGe(
            groveProxyBalanceBefore,
            GROVE_FOUNDATION_GRANT_AMOUNT,
            "grove-proxy-insufficient-balance"
        );

        executeAllPayloadsAndBridges();

        uint256 foundationBalanceAfter = usds.balanceOf(GROVE_FOUNDATION);
        uint256 groveProxyBalanceAfter = usds.balanceOf(Ethereum.GROVE_PROXY);

        assertEq(
            foundationBalanceAfter,
            foundationBalanceBefore + GROVE_FOUNDATION_GRANT_AMOUNT,
            "foundation-balance-not-increased"
        );

        assertEq(
            groveProxyBalanceAfter,
            groveProxyBalanceBefore - GROVE_FOUNDATION_GRANT_AMOUNT,
            "grove-proxy-balance-not-decreased"
        );
    }

}
