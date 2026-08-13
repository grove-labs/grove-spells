// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { IAccessControls }               from "diamond-pau/interfaces/IAccessControls.sol";
import { IRateLimits as IPauRateLimits } from "diamond-pau/interfaces/IRateLimits.sol";

import { GrovePauHelpers } from "src/libraries/helpers/GrovePauHelpers.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}

/**
 * @title  August 27, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260827 is GrovePayloadEthereum {

    address internal constant PAS_CONFIGURATOR = 0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929;

    function _execute() internal override {
        // [Ethereum] Item 1: Treasury Distribution of 800,000 USDS to the Grove Foundation Multisig.
        //   Forum : TODO
        _treasuryDistributionToGroveFoundation();

        // [Ethereum] Item 2: raise the UniswapV3 facet deposit rate limits to the next step of the ramp-up plan.
        //   Forum : TODO
        _raiseUniswapV3DepositRateLimits();

        // [Ethereum] Item 3: authorize the Sky PAS Configurator on the Grove DPAU access-control stack.
        //   Forum : TODO
        _authorizePasConfigurator();
    }

    function _treasuryDistributionToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(Ethereum.GROVE_FOUNDATION, 800_000e18));
    }

    function _raiseUniswapV3DepositRateLimits() internal {
        GrovePauHelpers.setUniswapV3DepositRateLimit({
            rateLimits     : Ethereum.PAU_RATE_LIMITS,
            pool           : Ethereum.UNISWAP_V3_AUSD_USDC,
            token0         : Ethereum.AUSD,
            token1         : Ethereum.USDC,
            aggregateMax   : 5_000_000e18,                 // BEFORE: 5_000_000e18
            aggregateSlope : 350_000e18 / uint256(1 days), // BEFORE: 0
            token0Max      : 5_000_000e6,                  // BEFORE: 5_000_000e6
            token0Slope    : 350_000e6 / uint256(1 days),  // BEFORE: 0
            token1Max      : 5_000_000e6,                  // BEFORE: 5_000_000e6
            token1Slope    : 350_000e6 / uint256(1 days)   // BEFORE: 0
        });
    }

    function _authorizePasConfigurator() internal {
        IAccessControls(Ethereum.PAU_ACCESS_CONTROLS).grantRole(DEFAULT_ADMIN_ROLE, PAS_CONFIGURATOR);
        IPauRateLimits(Ethereum.PAU_RATE_LIMITS).grantRole(DEFAULT_ADMIN_ROLE, PAS_CONFIGURATOR);
    }

}
