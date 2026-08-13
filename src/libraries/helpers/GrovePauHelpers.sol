// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IRateLimits }                           from "diamond-pau/interfaces/IRateLimits.sol";
import { makeAddressKey, makeAddressAddressKey } from "diamond-pau/libraries/RateLimitHelpers.sol";

/**
 * @notice Helper functions for the Grove Parallelized Allocation Unit (PAU)
 */
library GrovePauHelpers {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant LIMIT_BASIN_DEPOSIT  = keccak256("LIMIT_BASIN_DEPOSIT");
    bytes32 public constant LIMIT_BASIN_WITHDRAW = keccak256("LIMIT_BASIN_WITHDRAW");

    bytes32 public constant LIMIT_USDS_MINT    = keccak256("LIMIT_USDS_MINT");
    bytes32 public constant LIMIT_USDS_BURN    = keccak256("LIMIT_USDS_BURN");
    bytes32 public constant LIMIT_USDS_TO_USDC = keccak256("LIMIT_USDS_TO_USDC");
    bytes32 public constant LIMIT_USDC_TO_USDS = keccak256("LIMIT_USDC_TO_USDS");

    bytes32 public constant LIMIT_UNISWAP_V3_DEPOSIT = keccak256("LIMIT_UNISWAP_V3_DEPOSIT");

    /**********************************************************************************************/
    /*** USDS mint/burn functions                                                               ***/
    /**********************************************************************************************/

    /**
     * @notice Set the USDS mint and burn rate limits
     */
    function setUsdsMintBurnRateLimit(
        address rateLimits,
        uint256 mintMax,
        uint256 mintSlope,
        uint256 burnMax,
        uint256 burnSlope
    ) internal {
        IRateLimits(rateLimits).setRateLimitData(LIMIT_USDS_MINT, mintMax, mintSlope);
        IRateLimits(rateLimits).setRateLimitData(LIMIT_USDS_BURN, burnMax, burnSlope);
    }

    /**********************************************************************************************/
    /*** PSM swap functions                                                                     ***/
    /**********************************************************************************************/

    /**
     * @notice Set the PSM USDS<>USDC swap rate limits (both directions)
     * @dev Both directions must be set: swapUSDCToUSDS decreases the LIMIT_USDC_TO_USDS key
     *      (while refilling the LIMIT_USDS_TO_USDC key), so it reverts on an unset LIMIT_USDC_TO_USDS.
     */
    function setPsmSwapRateLimit(
        address rateLimits,
        uint256 usdsToUsdcMax,
        uint256 usdsToUsdcSlope,
        uint256 usdcToUsdsMax,
        uint256 usdcToUsdsSlope
    ) internal {
        IRateLimits(rateLimits).setRateLimitData(LIMIT_USDS_TO_USDC, usdsToUsdcMax, usdsToUsdcSlope);
        IRateLimits(rateLimits).setRateLimitData(LIMIT_USDC_TO_USDS, usdcToUsdsMax, usdcToUsdsSlope);
    }

    /**********************************************************************************************/
    /*** Basin functions                                                                        ***/
    /**********************************************************************************************/

    /**
     * @notice Set a Grove Basin's deposit and withdrawal rate limits
     * @dev Deposits are rate-limited on the deposited asset (USDS). Withdrawals are set as
     *      unlimited for both stable legs the basin pays out: the deposited asset (USDS) and the
     *      collateral its credit token redeems into (USDC), so the relayer can pull liquidity back
     *      out whichever side the pocket holds. The credit / RWA token is not withdrawable.
     */
    function setBasinRateLimit(
        address rateLimits,
        address basin,
        address depositAsset,
        address collateralAsset,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        IRateLimits(rateLimits).setRateLimitData(
            makeAddressAddressKey(LIMIT_BASIN_DEPOSIT, depositAsset, basin),
            depositMax,
            depositSlope
        );

        IRateLimits(rateLimits).setUnlimitedRateLimitData(
            makeAddressAddressKey(LIMIT_BASIN_WITHDRAW, depositAsset, basin)
        );
        IRateLimits(rateLimits).setUnlimitedRateLimitData(
            makeAddressAddressKey(LIMIT_BASIN_WITHDRAW, collateralAsset, basin)
        );
    }

    /**********************************************************************************************/
    /*** Uniswap V3 functions                                                                   ***/
    /**********************************************************************************************/

    /**
     * @notice Set a Uniswap V3 pool's deposit rate limits
     * @dev The three deposit keys must be set together: a deposit meters against the aggregate key
     *      and against the key of each token it supplies, so leaving one unset reverts the deposit.
     *      The aggregate key meters the 1e18-normalised sum across both pool tokens; the per-token
     *      keys meter raw amounts and so follow each token's own decimals.
     */
    function setUniswapV3DepositRateLimit(
        address rateLimits,
        address pool,
        address token0,
        address token1,
        uint256 aggregateMax,
        uint256 aggregateSlope,
        uint256 token0Max,
        uint256 token0Slope,
        uint256 token1Max,
        uint256 token1Slope
    ) internal {
        IRateLimits(rateLimits).setRateLimitData(
            makeAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, pool),
            aggregateMax,
            aggregateSlope
        );

        IRateLimits(rateLimits).setRateLimitData(
            makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, token0, pool),
            token0Max,
            token0Slope
        );
        IRateLimits(rateLimits).setRateLimitData(
            makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, token1, pool),
            token1Max,
            token1Slope
        );
    }

}
