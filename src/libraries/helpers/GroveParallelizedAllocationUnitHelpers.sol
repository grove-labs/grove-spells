// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { RateLimitHelpers } from "grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

/**
 * @notice Helper functions for the Grove Parallelized Allocation Unit (PAU)
 */
library GroveParallelizedAllocationUnitHelpers {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant LIMIT_BASIN_DEPOSIT  = keccak256("LIMIT_BASIN_DEPOSIT");
    bytes32 public constant LIMIT_BASIN_WITHDRAW = keccak256("LIMIT_BASIN_WITHDRAW");

    bytes32 public constant LIMIT_USDS_MINT    = keccak256("LIMIT_USDS_MINT");
    bytes32 public constant LIMIT_USDS_BURN    = keccak256("LIMIT_USDS_BURN");
    bytes32 public constant LIMIT_USDS_TO_USDC = keccak256("LIMIT_USDS_TO_USDC");
    bytes32 public constant LIMIT_USDC_TO_USDS = keccak256("LIMIT_USDC_TO_USDS");

    /**********************************************************************************************/
    /*** USDS mint/burn functions                                                               ***/
    /**********************************************************************************************/

    /**
     * @notice Onboard the USDS mint and burn rate limits
     */
    function onboardUsdsMintBurn(
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
     * @notice Onboard the PSM USDS<>USDC swap rate limits (both directions)
     * @dev Both directions must be onboarded: swapUSDCToUSDS decreases the usdcToUSDS key
     *      (while refilling the usdsToUSDC key), so it reverts on an unset usdcToUSDS limit.
     */
    function onboardPsmSwap(
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
     * @notice Onboard a Grove Basin
     * @dev Deposits are rate-limited on the deposited asset (USDS). Withdrawals are onboarded as
     *      unlimited for both stable legs the basin pays out: the deposited asset (USDS) and the
     *      collateral its credit token redeems into (USDC), so the relayer can pull liquidity back
     *      out whichever side the pocket holds. The credit / RWA token is not withdrawable.
     */
    function onboardBasin(
        address rateLimits,
        address basin,
        address depositAsset,
        address collateralAsset,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        IRateLimits(rateLimits).setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(LIMIT_BASIN_DEPOSIT, depositAsset, basin),
            depositMax,
            depositSlope
        );

        IRateLimits(rateLimits).setUnlimitedRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(LIMIT_BASIN_WITHDRAW, depositAsset, basin)
        );
        IRateLimits(rateLimits).setUnlimitedRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(LIMIT_BASIN_WITHDRAW, collateralAsset, basin)
        );
    }

}
