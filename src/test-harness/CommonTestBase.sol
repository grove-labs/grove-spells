// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5 <0.9.0;

import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { SpellRunner } from "./SpellRunner.sol";

interface ISecuritizeAssetLike {
  function issueTokens(address to, uint256 amount) external;
}

/// @dev Minimal read interface shared by the legacy ALM and PAU RateLimits
/// contracts, whose getRateLimitData ABIs are identical.
interface IRateLimitsLike {
  struct RateLimitData {
    uint256 maxAmount;
    uint256 slope;
    uint256 lastAmount;
    uint256 lastUpdated;
  }

  function getRateLimitData(bytes32 key) external view returns (RateLimitData memory data);
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

  address public constant AUSD_MAINNET  = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
  address public constant BUIDL_MAINNET = 0x6a9DA2D710BB9B700acde7Cb81F10F1fF8C89041;
  address public constant USDC_MAINNET  = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant STAC_MAINNET  = 0x51C2d74017390CbBd30550179A16A1c28F7210fc;

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
      // Securitize BUIDL
      if (asset == BUIDL_MAINNET) {
        address securitizeIssuer = 0xe01605f6b6dC593b7d2917F4a0940db2A625b09e;
        _securitizeIssueTokens(asset, user, securitizeIssuer, amount);
        return true;
      }
      // USDC
      if (asset == USDC_MAINNET) {
        address donor = 0xaD354CfBAa4A8572DD6Df021514a3931A8329Ef5;
        _transferFromDonor(asset, user, donor, amount);
        return true;
      }
      // Securitize STAC
      if (asset == STAC_MAINNET) {
        address securitizeIssuer = 0x22F53B51E4272F954f25BC377B1b759c6C5A528B;
        _securitizeIssueTokens(asset, user, securitizeIssuer, amount);
        return true;
      }
      // Agora AUSD
      if (asset == AUSD_MAINNET) {
        address donor = 0xe488A30Af596135A5c5313b3d4e7aABF985A0C0D;
        _transferFromDonor(asset, user, donor, amount);
        return true;
      }
    } else if (block.chainid == ChainIds.GNOSIS) {
      // EURe
      if (asset == EURE_GNOSIS) {
        address donor = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
        _transferFromDonor(asset, user, donor, amount);
        return true;
      }
      // USDC.e
      if (asset == USDCE_GNOSIS) {
        address donor = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
        _transferFromDonor(asset, user, donor, amount);
        return true;
      }
    } else if (block.chainid == ChainIds.BASE) {
      // USDC
      if (asset == USDC_BASE) {
        address donor = 0x8da91A6298eA5d1A8Bc985e99798fd0A0f05701a;
        _transferFromDonor(asset, user, donor, amount);
        return true;
      }
    }
    return false;
  }

  // NOTE: Deal behavior is to set the balance of the user to the amount, not send additional funds to the user
  //       so we are trying to replicate that as well as possible
  function _transferFromDonor(address asset, address user, address donor, uint256 amount) private {
    uint256 initialBalance = IERC20(asset).balanceOf(user);
    vm.prank(user);
    IERC20(asset).transfer(donor, initialBalance);
    vm.prank(donor);
    IERC20(asset).transfer(user, amount);
  }

  // NOTE: Deal behavior is to set the balance of the user to the amount, not send additional funds to the user
  //       so we are trying to replicate that as well as possible
  function _securitizeIssueTokens(address asset, address user, address issuer, uint256 amount) private {
    uint256 initialBalance = IERC20(asset).balanceOf(user);
    require(amount > initialBalance, "deal2/user-already-has-enough-balance");
    vm.prank(issuer);
    ISecuritizeAssetLike(asset).issueTokens(user, amount - initialBalance);
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

    function _assertRateLimit(
        address rateLimits,
        bytes32 key,
        uint256 maxAmount,
        uint256 slope,
        string memory errorPrefix
    ) internal view {
        IRateLimitsLike.RateLimitData memory rateLimit = IRateLimitsLike(rateLimits).getRateLimitData(key);

        assertEq(rateLimit.maxAmount, maxAmount, string.concat(errorPrefix, "max-amount-not-correct"));
        assertEq(rateLimit.slope,     slope,     string.concat(errorPrefix, "slope-not-correct"));
    }

    function _assertUnlimitedRateLimit(
        address rateLimits,
        bytes32 key,
        string memory errorPrefix
    ) internal view {
        IRateLimitsLike.RateLimitData memory rateLimit = IRateLimitsLike(rateLimits).getRateLimitData(key);

        assertEq(rateLimit.maxAmount, type(uint256).max, string.concat(errorPrefix, "unlimited-max-amount-not-correct"));
        assertEq(rateLimit.slope,     0, string.concat(errorPrefix, "unlimited-slope-not-correct"));
    }

    function _assertZeroRateLimit(
        address rateLimits,
        bytes32 key,
        string memory errorPrefix
    ) internal view {
        IRateLimitsLike.RateLimitData memory rateLimit = IRateLimitsLike(rateLimits).getRateLimitData(key);

        assertEq(rateLimit.maxAmount, 0, string.concat(errorPrefix, "zero-max-amount-not-correct"));
        assertEq(rateLimit.slope,     0, string.concat(errorPrefix, "zero-slope-not-correct"));
    }

    function _assertRateLimit(
        address rateLimits,
        bytes32 key,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated,
        string memory errorPrefix
    ) internal view {
        IRateLimitsLike.RateLimitData memory rateLimit = IRateLimitsLike(rateLimits).getRateLimitData(key);

        assertEq(rateLimit.maxAmount,   maxAmount,   string.concat(errorPrefix, "max-amount-not-correct"));
        assertEq(rateLimit.slope,       slope,       string.concat(errorPrefix, "slope-not-correct"));
        assertEq(rateLimit.lastAmount,  lastAmount,  string.concat(errorPrefix, "last-amount-not-correct"));
        assertEq(rateLimit.lastUpdated, lastUpdated, string.concat(errorPrefix, "last-updated-not-correct"));
    }

}
