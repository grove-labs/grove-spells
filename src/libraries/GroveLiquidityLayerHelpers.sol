// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { RateLimitHelpers } from "grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

/**
 * @notice Helper functions for Grove Liquidity Layer
 */
library GroveLiquidityLayerHelpers {

    // This is the same on all chains
    address private constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    bytes32 private constant LIMIT_4626_DEPOSIT  = keccak256("LIMIT_4626_DEPOSIT");
    bytes32 private constant LIMIT_4626_WITHDRAW = keccak256("LIMIT_4626_WITHDRAW");
    bytes32 private constant LIMIT_7540_DEPOSIT  = keccak256("LIMIT_7540_DEPOSIT");
    bytes32 private constant LIMIT_7540_REDEEM   = keccak256("LIMIT_7540_REDEEM");
    bytes32 private constant LIMIT_USDS_MINT     = keccak256("LIMIT_USDS_MINT");
    bytes32 private constant LIMIT_USDS_TO_USDC  = keccak256("LIMIT_USDS_TO_USDC");

    /**
     * @notice Onboard an ERC4626 vault
     * @dev This will set the deposit to the given numbers with
     *      the withdraw limit set to unlimited.
     */
    function onboardERC4626Vault(
        address rateLimits,
        address vault,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            LIMIT_4626_DEPOSIT,
            vault
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            LIMIT_4626_WITHDRAW,
            vault
        );

        IRateLimits(rateLimits).setRateLimitData(depositKey, depositMax, depositSlope);

        IRateLimits(rateLimits).setUnlimitedRateLimitData(withdrawKey);
    }

    /**
     * @notice Onboard an ERC7540 vault
     * @dev This will set the deposit to the given numbers with
     *      the redeem limit set to unlimited.
     */
    function onboardERC7540Vault(
        address rateLimits,
        address vault,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            LIMIT_7540_DEPOSIT,
            vault
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetKey(
            LIMIT_7540_REDEEM,
            vault
        );

        IRateLimits(rateLimits).setRateLimitData(depositKey, depositMax, depositSlope);
        IRateLimits(rateLimits).setUnlimitedRateLimitData(redeemKey);
    }

    function setUSDSMintRateLimit(
        address rateLimits,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        bytes32 mintKey = RateLimitHelpers.makeAssetKey(
            LIMIT_USDS_MINT,
            MORPHO
        );

        IRateLimits(rateLimits).setRateLimitData(mintKey, maxAmount, slope);
    }

    function setUSDSToUSDCRateLimit(
        address rateLimits,
        uint256 maxUsdcAmount,
        uint256 slope
    ) internal {
        bytes32 usdsToUsdcKey = RateLimitHelpers.makeAssetKey(
            LIMIT_USDS_TO_USDC,
            MORPHO
        );

        IRateLimits(rateLimits).setRateLimitData(usdsToUsdcKey, maxUsdcAmount, slope);
    }
}
