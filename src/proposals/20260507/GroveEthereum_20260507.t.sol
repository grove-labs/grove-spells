// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20260507_Test is GroveTestBase {

    address internal constant GROVE_X_STEAKHOUSE_RLUSD_V2 = 0xBeEff4fD39F8e48b6a6e475445D650cb11e9599F;

    address internal constant GROVE_FOUNDATION = 0xE3EC4CC359E68c9dCE15Bf667b1aD37Df54a5a42;

    uint256 internal constant GROVE_FOUNDATION_GRANT_AMOUNT = 800_000e18;

    constructor() {
        id = "20260507";
    }

    function setUp() public {
        setupDomains("2026-04-22T10:00:00Z");

        // Execute prior (20260423) payloads as dependencies for this spell
        chainData[ChainIdUtils.Avalanche()].newController = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;

        chainData[ChainIdUtils.Ethereum()].payload  = 0x76Ba24676e1055D3E6b160086f0bc9BaffF76929;
        chainData[ChainIdUtils.Avalanche()].payload = 0x1204f2C342706cE6B75997c89619D130Ee9dDa2c;
        executeAllPayloadsAndBridges();

        // After 20260423 upgraded the Avalanche controller, update prev/new to the post-upgrade address
        chainData[ChainIdUtils.Avalanche()].prevController = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;
        chainData[ChainIdUtils.Avalanche()].newController  = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;

        // Clear Avalanche payload to avoid executing it again
        chainData[ChainIdUtils.Avalanche()].payload = address(0);

        deployPayloads();
    }

    function test_ETHEREUM_onboardGroveBasin() public onChain(ChainIdUtils.Ethereum()) {
        // TODO Grove Basin onboarding - implementation WIP
        vm.skip(true);
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
