// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { IALMProxy }   from "lib/grove-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "lib/grove-alm-controller/src/interfaces/IRateLimits.sol";

import { INonfungiblePositionManager } from "lib/grove-alm-controller/src/interfaces/UniswapV3Interfaces.sol";

import { IRateLimits as IPauRateLimits }         from "diamond-pau/interfaces/IRateLimits.sol";
import { makeAddressKey, makeAddressAddressKey } from "diamond-pau/libraries/RateLimitHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IPauControllerLike {
    function updateIntegrations(bytes32[] calldata integrationIds) external;
    function uniswapV3_setLiquidityLowerTickBound(address pool, int24 lowerTickBound) external;
    function uniswapV3_setLiquidityUpperTickBound(address pool, int24 upperTickBound) external;
    function uniswapV3_setMaxSlippage(address pool, uint256 maxSlippage) external;
    function uniswapV3_setMaxTickDelta(address pool, uint24 maxTickDelta) external;
    function uniswapV3_setTWAPSecondsAgo(address pool, uint32 twapSecondsAgo) external;
}

/**
 * @title  August 13, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260813 is GrovePayloadEthereum {

    bytes32 internal constant UNISWAP_V3_FACET_ID = bytes32("UNISWAP_V3_FACET");

    bytes32 internal constant LIMIT_UNISWAP_V3_DEPOSIT  = keccak256("LIMIT_UNISWAP_V3_DEPOSIT");
    bytes32 internal constant LIMIT_UNISWAP_V3_SWAP     = keccak256("LIMIT_UNISWAP_V3_SWAP");
    bytes32 internal constant LIMIT_UNISWAP_V3_WITHDRAW = keccak256("LIMIT_UNISWAP_V3_WITHDRAW");

    // Grove AUSD/USDC position NFT held by the ALM Proxy.
    uint256 internal constant UNISWAP_V3_POSITION_TOKEN_ID = 1192575;

    function _execute() internal override {
        // [Ethereum] Item 1: enable the UniswapV3 facet on the Grove DPAU controller and onboard the AUSD/USDC pool.
        //   Forum : TODO
        _enableUniswapV3Facet();

        // [Ethereum] Item 2: one-time collect of accrued fees on the Grove Uniswap V3 ALM Controller position.
        //   Forum : TODO
        _collectUniswapV3PositionFees();

        // [Ethereum] Item 3: offboard the Maple syrupUSDC deposit rate limit.
        //   Forum : TODO
        _offboardMapleSyrupUsdcDepositRateLimit();
    }

    function _enableUniswapV3Facet() internal {
        IPauControllerLike controller = IPauControllerLike(Ethereum.PAU_CONTROLLER);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = UNISWAP_V3_FACET_ID;

        controller.updateIntegrations(integrationIds);

        // Mirrors the live ALM-side AUSD/USDC config (archive/20260129/GroveEthereum_20260129.sol).
        controller.uniswapV3_setMaxSlippage(Ethereum.UNISWAP_V3_AUSD_USDC, 0.999e18);
        controller.uniswapV3_setMaxTickDelta(Ethereum.UNISWAP_V3_AUSD_USDC, 200);
        controller.uniswapV3_setTWAPSecondsAgo(Ethereum.UNISWAP_V3_AUSD_USDC, 600);
        controller.uniswapV3_setLiquidityLowerTickBound(Ethereum.UNISWAP_V3_AUSD_USDC, -10);
        controller.uniswapV3_setLiquidityUpperTickBound(Ethereum.UNISWAP_V3_AUSD_USDC, 10);

        // Rate limits follow the facet ramp-up risk parameters, not the Jan 29 ALM-side values.
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setRateLimitData({
            key       : makeAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.UNISWAP_V3_AUSD_USDC),
            maxAmount : 5_000_000e18,  // BEFORE: 0
            slope     : 0              // BEFORE: 0
        });
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setRateLimitData({
            key       : makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC),
            maxAmount : 5_000_000e6,  // BEFORE: 0
            slope     : 0             // BEFORE: 0
        });
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setRateLimitData({
            key       : makeAddressAddressKey(LIMIT_UNISWAP_V3_DEPOSIT, Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC),
            maxAmount : 5_000_000e6,  // BEFORE: 0
            slope     : 0             // BEFORE: 0
        });

        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setUnlimitedRateLimitData(
            makeAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.UNISWAP_V3_AUSD_USDC)
        );
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setUnlimitedRateLimitData(
            makeAddressAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC)
        );
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setUnlimitedRateLimitData(
            makeAddressAddressKey(LIMIT_UNISWAP_V3_WITHDRAW, Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC)
        );

        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setRateLimitData({
            key       : makeAddressAddressKey(LIMIT_UNISWAP_V3_SWAP, Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC),
            maxAmount : 1_000_000e6,                   // BEFORE: 0
            slope     : 5_000_000e6 / uint256(1 days)  // BEFORE: 0
        });
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).setRateLimitData({
            key       : makeAddressAddressKey(LIMIT_UNISWAP_V3_SWAP, Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC),
            maxAmount : 1_000_000e6,                   // BEFORE: 0
            slope     : 5_000_000e6 / uint256(1 days)  // BEFORE: 0
        });
    }

    function _collectUniswapV3PositionFees() internal {
        IALMProxy almProxy = IALMProxy(Ethereum.ALM_PROXY);

        almProxy.grantRole(almProxy.CONTROLLER(), Ethereum.GROVE_PROXY);

        almProxy.doCall(
            Ethereum.UNISWAP_V3_POSITION_MANAGER,
            abi.encodeCall(
                INonfungiblePositionManager.collect,
                INonfungiblePositionManager.CollectParams({
                    tokenId    : UNISWAP_V3_POSITION_TOKEN_ID,
                    recipient  : Ethereum.ALM_PROXY,
                    amount0Max : type(uint128).max,
                    amount1Max : type(uint128).max
                })
            )
        );

        almProxy.revokeRole(almProxy.CONTROLLER(), Ethereum.GROVE_PROXY);
    }

    function _offboardMapleSyrupUsdcDepositRateLimit() internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_4626_DEPOSIT(),
            Ethereum.MAPLE_SYRUP_USDC
        );

        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData({
            key       : depositKey,
            maxAmount : 0,  // BEFORE: 50_000_000e6
            slope     : 0   // BEFORE: 50_000_000e6 / 1 days
        });
    }

}
