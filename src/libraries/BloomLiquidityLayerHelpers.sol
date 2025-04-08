// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { RateLimitHelpers, RateLimitData } from "bloom-alm-controller/src/RateLimitHelpers.sol";

/**
 * @notice Helper functions for Bloom Liquidity Layer
 */
library BloomLiquidityLayerHelpers {

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
        IERC20 asset = IERC20(IERC4626(vault).asset());

        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                LIMIT_4626_DEPOSIT,
                vault
            ),
            rateLimits,
            RateLimitData({
                maxAmount : depositMax,
                slope     : depositSlope
            }),
            "erc4626VaultDepositLimit",
            asset.decimals()
        );
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                LIMIT_4626_WITHDRAW,
                vault
            ),
            rateLimits,
            RateLimitHelpers.unlimitedRateLimit(),
            "erc4626VaultWithdrawLimit",
            asset.decimals()
        );
    }

    function onboardERC7540Vault(
        address rateLimits,
        address vault,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        // ERC7540 vaults are obliged to implement ERC4626 as well
        IERC20 asset = IERC20(IERC4626(vault).asset());

        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                LIMIT_7540_DEPOSIT,
                vault
            ),
            rateLimits,
            RateLimitData({
                maxAmount : depositMax,
                slope     : depositSlope
            }),
            "erc7540VaultDepositLimit",
            asset.decimals()
        );

        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                LIMIT_7540_REDEEM,
                vault
            ),
            rateLimits,
            RateLimitHelpers.unlimitedRateLimit(),
            "erc7540VaultRedeemLimit",
            asset.decimals()
        );
    }

    function setUSDSMintRateLimit(
        address rateLimits,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        RateLimitHelpers.setRateLimitData(
            LIMIT_USDS_MINT,
            rateLimits,
            RateLimitData({
                maxAmount : maxAmount,
                slope     : slope
            }),
            "USDS mint limit",
            18
        );
    }

    function setUSDSToUSDCRateLimit(
        address rateLimits,
        uint256 maxUsdcAmount,
        uint256 slope
    ) internal {
        RateLimitHelpers.setRateLimitData(
            LIMIT_USDS_TO_USDC,
            rateLimits,
            RateLimitData({
                maxAmount : maxUsdcAmount,
                slope     : slope
            }),
            "Swap USDS to USDC limit",
            6
        );
    }
}
