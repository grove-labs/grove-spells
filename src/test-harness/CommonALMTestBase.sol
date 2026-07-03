// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { IALMProxy }   from "grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

import { ChainId, ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { CommonTestBase } from "./CommonTestBase.sol";

struct GroveLiquidityLayerContext {
    address     admin;
    address     controller;
    IALMProxy   proxy;
    IRateLimits rateLimits;
    address     relayer;
    address     freezer;
}

/// @dev Test base for the legacy ALM controller system
/// (grove-alm-controller MainnetController/ForeignController + ALM_PROXY).
abstract contract CommonALMTestBase is CommonTestBase {

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
      } else if (chain == ChainIdUtils.Plume()) {
          ctx = GroveLiquidityLayerContext(
              Plume.GROVE_EXECUTOR,
              controller,
              IALMProxy(Plume.ALM_PROXY),
              IRateLimits(Plume.ALM_RATE_LIMITS),
              Plume.ALM_RELAYER,
              Plume.ALM_FREEZER
          );
      } else if (chain == ChainIdUtils.Robinhood()) {
          // Robinhood addresses inlined as local literals until grove-address-registry
          // exposes Robinhood.* references (swapped in the archive PR)
          ctx = GroveLiquidityLayerContext(
              0x5ff98717a18833de1A49e11B498866d6Fa1c9296,             // GROVE_EXECUTOR
              controller,
              IALMProxy(0x29626c2d8Ca49A51E4dECEEc5499e52983c42BD5),  // ALM_PROXY
              IRateLimits(0xC13e5ff7993c5df911aE562a7736B0eBA12b2010), // ALM_RATE_LIMITS
              0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f,             // ALM_RELAYER
              0xB0113804960345fd0a245788b3423319c86940e5              // ALM_FREEZER
          );
      } else {
          revert("Chain not supported by GroveLiquidityLayerContext");
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
        _assertRateLimit(address(_getGroveLiquidityLayerContext().rateLimits), key, maxAmount, slope, "");
    }

    function _assertUnlimitedRateLimit(
        bytes32 key
    ) internal view {
        _assertUnlimitedRateLimit(address(_getGroveLiquidityLayerContext().rateLimits), key, "");
    }

    function _assertZeroRateLimit(
        bytes32 key
    ) internal view {
        _assertZeroRateLimit(address(_getGroveLiquidityLayerContext().rateLimits), key, "");
    }

    function _assertRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    ) internal view {
        _assertRateLimit(address(_getGroveLiquidityLayerContext().rateLimits), key, maxAmount, slope, lastAmount, lastUpdated, "");
    }

}
