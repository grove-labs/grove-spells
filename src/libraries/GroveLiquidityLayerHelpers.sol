// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "grove-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";

/**
 * @notice Helper functions for Grove Liquidity Layer
 */
library GroveLiquidityLayerHelpers {

    // This is the same on all chains
    address private constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address public constant BLANK_ADDRESS_PLACEHOLDER = 0x00000000000000000000000000000000DeaDBeef;

    bytes32 public constant LIMIT_4626_DEPOSIT        = keccak256("LIMIT_4626_DEPOSIT");
    bytes32 public constant LIMIT_4626_WITHDRAW       = keccak256("LIMIT_4626_WITHDRAW");
    bytes32 public constant LIMIT_7540_DEPOSIT        = keccak256("LIMIT_7540_DEPOSIT");
    bytes32 public constant LIMIT_7540_REDEEM         = keccak256("LIMIT_7540_REDEEM");
    bytes32 public constant LIMIT_USDS_MINT           = keccak256("LIMIT_USDS_MINT");
    bytes32 public constant LIMIT_USDS_TO_USDC        = keccak256("LIMIT_USDS_TO_USDC");
    bytes32 public constant LIMIT_CENTRIFUGE_TRANSFER = keccak256("LIMIT_CENTRIFUGE_TRANSFER");
    bytes32 public constant LIMIT_AAVE_DEPOSIT        = keccak256("LIMIT_AAVE_DEPOSIT");
    bytes32 public constant LIMIT_AAVE_WITHDRAW       = keccak256("LIMIT_AAVE_WITHDRAW");
    bytes32 public constant LIMIT_CURVE_DEPOSIT       = keccak256("LIMIT_CURVE_DEPOSIT");
    bytes32 public constant LIMIT_CURVE_SWAP          = keccak256("LIMIT_CURVE_SWAP");
    bytes32 public constant LIMIT_CURVE_WITHDRAW      = keccak256("LIMIT_CURVE_WITHDRAW");

    uint16 public constant  ETHEREUM_DESTINATION_CENTRIFUGE_ID = 1;
    uint16 public constant     PLUME_DESTINATION_CENTRIFUGE_ID = 4;
    uint16 public constant AVALANCHE_DESTINATION_CENTRIFUGE_ID = 5;

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

    function offboardERC7540Vault(
        address rateLimits,
        address vault
    ) internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            LIMIT_7540_DEPOSIT,
            vault
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetKey(
            LIMIT_7540_REDEEM,
            vault
        );

        IRateLimits(rateLimits).setRateLimitData(depositKey, 0, 0);
        IRateLimits(rateLimits).setRateLimitData(redeemKey,  0, 0);
    }

    /**
     * @notice Onboard an Aave token
     * @dev This will set the deposit to the given numbers with
     *      the withdraw limit set to unlimited.
     */
    function onboardAaveToken(
        address rateLimits,
        address token,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            LIMIT_AAVE_DEPOSIT,
            token
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            LIMIT_AAVE_WITHDRAW,
            token
        );

        IRateLimits(rateLimits).setRateLimitData(depositKey, depositMax, depositSlope);
        IRateLimits(rateLimits).setUnlimitedRateLimitData(withdrawKey);
    }

    /**
     * @notice Onboard a Curve pool
     */
    function onboardCurvePool(
        address controller,
        address rateLimits,
        address pool,
        uint256 maxSlippage,
        uint256 swapMax,
        uint256 swapSlope,
        uint256 depositMax,
        uint256 depositSlope,
        uint256 withdrawMax,
        uint256 withdrawSlope
    ) internal {
        MainnetController(controller).setMaxSlippage(pool, maxSlippage);

        if (swapMax != 0) {
            bytes32 swapKey = RateLimitHelpers.makeAssetKey(
                LIMIT_CURVE_SWAP,
                pool
            );
            IRateLimits(rateLimits).setRateLimitData(swapKey, swapMax, swapSlope);
        }

        if (depositMax != 0) {
            bytes32 depositKey = RateLimitHelpers.makeAssetKey(
                LIMIT_CURVE_DEPOSIT,
                pool
            );
            IRateLimits(rateLimits).setRateLimitData(depositKey, depositMax, depositSlope);
        }

        if (withdrawMax != 0) {
            bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
                LIMIT_CURVE_WITHDRAW,
                pool
            );
            IRateLimits(rateLimits).setRateLimitData(withdrawKey, withdrawMax, withdrawSlope);
        }
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

    function setCentrifugeCrosschainTransferRateLimit(
        address rateLimits,
        address centrifugeVault,
        uint16  destinationCentrifugeId,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        bytes32 centrifugeCrosschainTransferKey = keccak256(abi.encode(LIMIT_CENTRIFUGE_TRANSFER, centrifugeVault, destinationCentrifugeId));

        IRateLimits(rateLimits).setRateLimitData(centrifugeCrosschainTransferKey, maxAmount, slope);
    }

}
