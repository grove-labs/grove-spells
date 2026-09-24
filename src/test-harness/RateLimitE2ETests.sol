// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { Category, RateLimitIntegration } from "./CommonRateLimitTests.sol";
import { GroveLiquidityLayerContext }     from "./CommonALMTestBase.sol";
import { RateLimitRegistry }              from "./RateLimitRegistry.sol";

/// @dev Exercises onboarded integrations against live chain state: enter with real funds,
/// assert the rate limit moves and the position appears, then exit. The coverage gate
/// proves a limit is configured; this proves the integration behind it still works.
/// Each integration runs inside a snapshot so they cannot affect one another.
abstract contract RateLimitE2ETests is RateLimitRegistry {

    /// @dev Entry size, in whole units of the integration's asset. Small enough to sit
    /// under any sane rate limit, large enough not to round to zero shares.
    uint256 internal constant E2E_UNITS = 1000;

    /// @dev Wei of vault shares a round trip may lose to rounding in the vault's favour.
    uint256 internal constant SHARE_DUST = 2;

    /// @dev Wei of the underlying a round trip may lose to the same rounding.
    uint256 internal constant ASSET_DUST = 2;

    function test_ETHEREUM_AlmIntegrationsOperational() public onChain(ChainIdUtils.Ethereum()) {
        _testIntegrationsOperational(_almIntegrations());
    }

    function test_BASE_IntegrationsOperational() public onChain(ChainIdUtils.Base()) {
        _testIntegrationsOperational(_almIntegrations());
    }

    function test_ROBINHOOD_IntegrationsOperational() public onChain(ChainIdUtils.Robinhood()) {
        _testIntegrationsOperational(_almIntegrations());
    }

    /// @dev Runs every integration even if one fails, so a broken integration does not
    /// hide the state of the rest, then fails once with the whole picture logged.
    function _testIntegrationsOperational(RateLimitIntegration[] memory integrations) internal {
        uint256 failures;

        for (uint256 i; i < integrations.length; ++i) {
            uint256 snapshot = vm.snapshotState();

            try this.runIntegration(integrations[i]) {}
            catch Error(string memory reason) {
                console.log("E2E failed:", integrations[i].label, reason);
                ++failures;
            }
            catch (bytes memory data) {
                console.log("E2E failed:", integrations[i].label, vm.toString(data));
                ++failures;
            }

            vm.revertToState(snapshot);
        }

        assertEq(failures, 0, "RateLimitE2ETests/integrations-not-operational");
    }

    /// @dev External only so the loop above can catch a revert; not meant to be called.
    function runIntegration(RateLimitIntegration memory integration) external {
        require(msg.sender == address(this), "RateLimitE2ETests/internal-only");

        _runIntegration(integration);
    }

    /// @dev Categories land one at a time; anything without a runner yet is skipped rather
    /// than silently passing, so the gap stays visible in the logs.
    function _runIntegration(RateLimitIntegration memory integration) internal {
        if (integration.category == Category.ERC4626) {
            _testERC4626Operational(integration);
            return;
        }

        console.log("No E2E runner yet:", integration.label);
    }

    function _testERC4626Operational(RateLimitIntegration memory integration) private {
        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        IERC4626 vault = IERC4626(integration.integration);
        IERC20   asset = IERC20(integration.asset);

        uint256 amount = _entryAmount(ctx, integration, vault);

        uint256 startingShares = vault.balanceOf(address(ctx.proxy));
        uint256 startingAssets = vault.convertToAssets(startingShares);

        uint256 entryLimit = ctx.rateLimits.getCurrentRateLimit(integration.entryId);

        // The proxy often already holds the asset, and dealing over a live balance is both
        // unnecessary and, for proxied tokens whose balance slot cannot be located, harmful:
        // the search overwrites the implementation slot and bricks the token mid-test.
        if (asset.balanceOf(address(ctx.proxy)) < amount) {
            deal2(address(asset), address(ctx.proxy), amount);
        }

        uint256 assetsBefore = asset.balanceOf(address(ctx.proxy));

        vm.prank(ctx.relayer);
        uint256 shares = MainnetController(ctx.controller).depositERC4626(address(vault), amount);

        if (entryLimit != type(uint256).max) {
            assertEq(
                ctx.rateLimits.getCurrentRateLimit(integration.entryId),
                entryLimit - amount,
                string(abi.encodePacked("entry limit not debited ", integration.label))
            );
        }

        assertEq(
            asset.balanceOf(address(ctx.proxy)),
            assetsBefore - amount,
            string(abi.encodePacked("assets not pulled in ", integration.label))
        );

        assertGt(
            vault.convertToAssets(vault.balanceOf(address(ctx.proxy))),
            startingAssets,
            string(abi.encodePacked("position did not grow ", integration.label))
        );

        // sUSDE exits through a cooldown and Maple through a withdrawal queue, so neither
        // onboarded a 4626 withdraw limit. Those integrations are entry-only here.
        if (integration.exitId == bytes32(0)) return;

        // Exit on what the deposit actually minted rather than the nominal amount. A
        // deposit rounds shares down, so asking for the full amount back can need one
        // more share than it produced and revert on a position that started empty.
        uint256 exitAmount = vault.previewRedeem(shares);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).withdrawERC4626(address(vault), exitAmount);

        assertEq(
            asset.balanceOf(address(ctx.proxy)),
            assetsBefore - amount + exitAmount,
            string(abi.encodePacked("assets not returned ", integration.label))
        );

        assertApproxEqAbs(
            exitAmount,
            amount,
            ASSET_DUST,
            string(abi.encodePacked("round trip lost value ", integration.label))
        );

        assertGe(
            vault.balanceOf(address(ctx.proxy)) + SHARE_DUST,
            startingShares,
            string(abi.encodePacked("shares lost ", integration.label))
        );
    }

    /// @dev Sized against the rate limit and the vault's own cap so the entry is testing
    /// the integration rather than a limit that happens to be smaller than the test. A
    /// zero cap is treated as unknown rather than full: Morpho Vault V2 gates maxDeposit
    /// and reports zero even with room, so the deposit itself is left to be the judge.
    function _entryAmount(
        GroveLiquidityLayerContext memory ctx,
        RateLimitIntegration       memory integration,
        IERC4626                          vault
    ) private view returns (uint256 amount) {
        amount = E2E_UNITS * 10 ** IERC20(integration.asset).decimals();

        uint256 limit = ctx.rateLimits.getCurrentRateLimit(integration.entryId);
        uint256 cap   = vault.maxDeposit(address(ctx.proxy));

        if (limit < amount)            amount = limit;
        if (cap   < amount && cap > 0) amount = cap;

        require(amount > 0, string(abi.encodePacked("no capacity ", integration.label)));
    }

}
