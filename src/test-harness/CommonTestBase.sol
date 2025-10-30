// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5 <0.9.0;

import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";
import { Plasma }    from "lib/grove-address-registry/src/Plasma.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { IALMProxy }   from "grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { ChainId, ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { SpellRunner } from "./SpellRunner.sol";

struct GroveLiquidityLayerContext {
    address     admin;
    address     controller;
    IALMProxy   proxy;
    IRateLimits rateLimits;
    address     relayer;
    address     freezer;
}

library ChainIds {
    uint256 internal constant MAINNET   = 1;
    uint256 internal constant ARBITRUM  = 42161;
    uint256 internal constant AVALANCHE = 43114;
    uint256 internal constant BASE      = 8453;
    uint256 internal constant FANTOM    = 250;
    uint256 internal constant GNOSIS    = 100;
    uint256 internal constant HARMONY   = 1666600000;
    uint256 internal constant METIS     = 1088;
    uint256 internal constant OPTIMISM  = 10;
    uint256 internal constant POLYGON   = 137;
    uint256 internal constant PLASMA    = 9745;
    uint256 internal constant PLUME     = 98866;
    uint256 internal constant UNICHAIN  = 130;
  }

contract CommonTestBase is SpellRunner {
  using stdJson for string;

  bytes32 internal constant GROVE_ALLOCATOR_ILK = "ALLOCATOR-BLOOM-A";

  address public constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  address public constant EURE_GNOSIS  = 0xcB444e90D8198415266c6a2724b7900fb12FC56E;
  address public constant USDCE_GNOSIS = 0x2a22f9c3b484c3629090FeED35F17Ff8F88f76F0;

  address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

  /**
   * @notice deal doesn"t support amounts stored in a script right now.
   * This function patches deal to mock and transfer funds instead.
   * @param asset the asset to deal
   * @param user the user to deal to
   * @param amount the amount to deal
   * @return bool true if the caller has changed due to prank usage
   */
  function _patchedDeal(address asset, address user, uint256 amount) internal returns (bool) {
    if (block.chainid == ChainIds.MAINNET) {
      // USDC
      if (asset == USDC_MAINNET) {
        vm.prank(0x28C6c06298d514Db089934071355E5743bf21d60);
        IERC20(asset).transfer(user, amount);
        return true;
      }
    } else if (block.chainid == ChainIds.GNOSIS) {
      // EURe
      if (asset == EURE_GNOSIS) {
        vm.prank(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        IERC20(asset).transfer(user, amount);
        return true;
      }
      // USDC.e
      if (asset == USDCE_GNOSIS) {
        vm.prank(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        IERC20(asset).transfer(user, amount);
        return true;
      }
    } else if (block.chainid == ChainIds.BASE) {
      // USDC
      if (asset == USDC_BASE) {
        vm.prank(0x7C310a03f4CFa19F7f3d7F36DD3E05828629fa78);
        IERC20(asset).transfer(user, amount);
        return true;
      }
    }
    return false;
  }

  /**
   * Patched version of deal
   * @param asset to deal
   * @param user to deal to
   * @param amount to deal
   */
  function deal2(address asset, address user, uint256 amount) internal {
    bool patched = _patchedDeal(asset, user, amount);
    if (!patched) {
      deal(asset, user, amount);
    }
  }

  /**
   * @dev forwards time by x blocks
   */
  function _skipBlocks(uint128 blocks) internal {
    vm.roll(block.number + blocks);
    vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
  }

  function _isInUint256Array(
    uint256[] memory haystack,
    uint256 needle
  ) internal pure returns (bool) {
    for (uint256 i = 0; i < haystack.length; i++) {
      if (haystack[i] == needle) return true;
    }
    return false;
  }

  function _isInAddressArray(
    address[] memory haystack,
    address needle
  ) internal pure returns (bool) {
    for (uint256 i = 0; i < haystack.length; i++) {
      if (haystack[i] == needle) return true;
    }
    return false;
  }

  function _getGroveLiquidityLayerContext(ChainId chain) internal view returns(GroveLiquidityLayerContext memory ctx) {
      address controller;
      if(chainData[chain].spellExecuted) {
          controller = chainData[chain].newController;
      } else {
          controller = chainData[chain].prevController;
      }
      if (chain == ChainIdUtils.Ethereum()) {
          ctx = GroveLiquidityLayerContext(
              Ethereum.GROVE_PROXY,
              controller,
              IALMProxy(Ethereum.ALM_PROXY),
              IRateLimits(Ethereum.ALM_RATE_LIMITS),
              Ethereum.ALM_RELAYER,
              Ethereum.ALM_FREEZER
      );
      } else if (chain == ChainIdUtils.Avalanche()) {
          ctx = GroveLiquidityLayerContext(
              Avalanche.GROVE_EXECUTOR,
              controller,
              IALMProxy(Avalanche.ALM_PROXY),
              IRateLimits(Avalanche.ALM_RATE_LIMITS),
              Avalanche.ALM_RELAYER,
              Avalanche.ALM_FREEZER
          );
      } else if (chain == ChainIdUtils.Base()) {
          ctx = GroveLiquidityLayerContext(
              Base.GROVE_EXECUTOR,
              controller,
              IALMProxy(Base.ALM_PROXY),
              IRateLimits(Base.ALM_RATE_LIMITS),
              Base.ALM_RELAYER,
              Base.ALM_FREEZER
          );
      } else if (chain == ChainIdUtils.Plasma()) {
          ctx = GroveLiquidityLayerContext(
              Plasma.GROVE_EXECUTOR,
              controller,
              IALMProxy(Plasma.ALM_PROXY),
              IRateLimits(Plasma.ALM_RATE_LIMITS),
              Plasma.ALM_RELAYER,
              Plasma.ALM_FREEZER
          );
      } else if (chain == ChainIdUtils.Plume()) {
          ctx = GroveLiquidityLayerContext(
              Plume.GROVE_EXECUTOR,
              controller,
              IALMProxy(Plume.ALM_PROXY),
              IRateLimits(Plume.ALM_RATE_LIMITS),
              Plume.ALM_RELAYER,
              Plume.ALM_FREEZER
          );
      } else {
          revert("Chain not supported by GroveLiquidityLayerTests context");
      }
  }

  function _getGroveLiquidityLayerContext() internal view returns(GroveLiquidityLayerContext memory) {
      return _getGroveLiquidityLayerContext(ChainIdUtils.fromUint(block.chainid));
  }

    /**
     * @notice Asserts the USDS and USDC balances of the ALM proxy
     * @param usds The expected USDS balance
     * @param usdc The expected USDC balance
     */
    function _assertMainnetAlmProxyBalances(
        uint256 usds,
        uint256 usdc
    ) internal view {
        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.ALM_PROXY), usds, "incorrect-alm-proxy-usds-balance");
        assertEq(IERC20(Ethereum.USDC).balanceOf(Ethereum.ALM_PROXY), usdc, "incorrect-alm-proxy-usdc-balance");
    }

    function _assertRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getGroveLiquidityLayerContext().rateLimits.getRateLimitData(key);

        assertEq(rateLimit.maxAmount, maxAmount);
        assertEq(rateLimit.slope,     slope);
    }

    function _assertUnlimitedRateLimit(
        bytes32 key
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getGroveLiquidityLayerContext().rateLimits.getRateLimitData(key);

        assertEq(rateLimit.maxAmount, type(uint256).max);
        assertEq(rateLimit.slope,     0);
    }

    function _assertZeroRateLimit(
        bytes32 key
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getGroveLiquidityLayerContext().rateLimits.getRateLimitData(key);

        assertEq(rateLimit.maxAmount, 0);
        assertEq(rateLimit.slope,     0);
    }

    function _assertRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getGroveLiquidityLayerContext().rateLimits.getRateLimitData(key);

        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  lastAmount);
        assertEq(rateLimit.lastUpdated, lastUpdated);
    }

}
