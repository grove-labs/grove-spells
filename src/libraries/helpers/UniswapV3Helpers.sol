// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IUniswapV3PoolLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

library UniswapV3Helpers {

    struct UniswapV3PoolParams {
        uint256 maxSlippage;
        uint24  maxTickDelta;
        uint32  twapSecondsAgo;
        int24   lowerTickBound;
        int24   upperTickBound;
    }

    struct UniswapV3TokenParams {
        uint256 swapMax;
        uint256 swapSlope;
        uint256 depositMax;
        uint256 depositSlope;
        uint256 withdrawMax;
        uint256 withdrawSlope;
    }

}
