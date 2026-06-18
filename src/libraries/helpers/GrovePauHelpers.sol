// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

// TODO: Remove the local IPauRateLimitsLike interface and RateLimitHelpers library below and
//       instead import them directly from diamond-pau (IRateLimits + RateLimitHelpers).
// NOTE: They mirror diamond-pau (v1.13.0) so this helper can build under the repo's current
//       solc 0.8.25, and can be swapped for the direct imports once the compiler is bumped to ^0.8.34.

/// @dev Mirrors the subset of diamond-pau's IRateLimits used here.
interface IPauRateLimitsLike {
    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope) external;
    function setUnlimitedRateLimitData(bytes32 key) external;
}

/// @dev Mirrors the subset of diamond-pau's RateLimitHelpers for local use.
///            https://github.com/sky-ecosystem/diamond-pau/blob/5c5ad6ae174bf467081ca82342ced2bd42a5c732/src/libraries/RateLimitHelpers.sol#L8-L10
library RateLimitHelpers {
    function makeAddressAddressKey(bytes32 key, address a, address b) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, a, b));
    }
}

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
        IPauRateLimitsLike(rateLimits).setRateLimitData(LIMIT_USDS_MINT, mintMax, mintSlope);
        IPauRateLimitsLike(rateLimits).setRateLimitData(LIMIT_USDS_BURN, burnMax, burnSlope);
    }

    /**********************************************************************************************/
    /*** PSM swap functions                                                                     ***/
    /**********************************************************************************************/

    /**
     * @notice Set the PSM USDS<>USDC swap rate limits (both directions)
     * @dev Both directions must be set: swapUSDCToUSDS decreases the usdcToUSDS key
     *      (while refilling the usdsToUSDC key), so it reverts on an unset usdcToUSDS limit.
     */
    function setPsmSwapRateLimit(
        address rateLimits,
        uint256 usdsToUsdcMax,
        uint256 usdsToUsdcSlope,
        uint256 usdcToUsdsMax,
        uint256 usdcToUsdsSlope
    ) internal {
        IPauRateLimitsLike(rateLimits).setRateLimitData(LIMIT_USDS_TO_USDC, usdsToUsdcMax, usdsToUsdcSlope);
        IPauRateLimitsLike(rateLimits).setRateLimitData(LIMIT_USDC_TO_USDS, usdcToUsdsMax, usdcToUsdsSlope);
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
        IPauRateLimitsLike(rateLimits).setRateLimitData(
            RateLimitHelpers.makeAddressAddressKey(LIMIT_BASIN_DEPOSIT, depositAsset, basin),
            depositMax,
            depositSlope
        );

        IPauRateLimitsLike(rateLimits).setUnlimitedRateLimitData(
            RateLimitHelpers.makeAddressAddressKey(LIMIT_BASIN_WITHDRAW, depositAsset, basin)
        );
        IPauRateLimitsLike(rateLimits).setUnlimitedRateLimitData(
            RateLimitHelpers.makeAddressAddressKey(LIMIT_BASIN_WITHDRAW, collateralAsset, basin)
        );
    }

}
