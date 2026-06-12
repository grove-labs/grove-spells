// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IUsdsPsmWrapperLike {
    function sellGem(address usr, uint256 gemAmt) external returns (uint256 usdsOut);
}

interface IDiamondPauControllerLike {
    function usds_setVault(address vault) external;
}

interface IAllocatorVaultLike {
    function rely(address usr) external;
}

interface IAllocatorBufferLike {
    function approve(address asset, address spender, uint256 amount) external;
}

/**
 * @title  July 2, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260702 is GrovePayloadEthereum {

    address internal constant DPAU_PROXY       = 0x0DcD9298e163dFD3c0B5b00F0d9093C36e40A153;
    address internal constant DPAU_CONTROLLER  = 0xbf83F5974B932c7D842254042717D6A2706CE5eE;
    address internal constant DPAU_RATE_LIMITS = 0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1;

    address internal constant ALLOCATOR_GROVE_A_VAULT  = 0xf739a30c74927dc6cFA3B67E4933872a1FC5F4EB;
    address internal constant ALLOCATOR_GROVE_A_BUFFER = 0x436DABce608f73BeA2b75fba35bffe72739697d5;

    address internal constant JTRSY_GROVE_BASIN = 0xf08943f817e1F902dEbC884c7B19Ea5764594Ac9;
    address internal constant BUIDL_GROVE_BASIN = 0xCBa428fB052B365557DAf52b744DFfF20d5FbEdD;

    function _execute() internal override {
        // [Ethereum] Initialize the DPAU system: hook it up to the new ALLOCATOR-GROVE-A instance (USDS mint/burn)
        //   Forum : TODO
        _initDpauSystem();

        // [Ethereum] Add USDS mint/burn rate limits on the DPAU rate limits (and reduce the legacy ALM mint limit to keep the total constant)
        //   Forum : TODO
        _onboardUsdsMintBurnRateLimits();

        // [Ethereum] Add PSM USDS<>USDC swap rate limits (both directions) on the DPAU rate limits (and reduce the legacy ALM swap limit to keep the total constant)
        //   Forum : TODO
        _onboardPsmSwapRateLimits();

        // [Ethereum] Add New Rate Limits for JTRSY Basin (relayer-driven USDS deposits + unlimited withdrawals)
        //   Forum : TODO
        _onboardJtrsyBasin();

        // [Ethereum] Add New Rate Limits for BUIDL Basin (relayer-driven USDS deposits + unlimited withdrawals)
        //   Forum : TODO
        _onboardBuidlBasin();

        // [Ethereum] Swap USDC to USDS in Grove SubProxy
        //   Forum : TODO
        _swapUsdcToUsdsViaPsm();

        // [Ethereum] Treasury Distribution to Grove Foundation
        //   Forum : TODO
        _treasuryDistributionToGroveFoundation();
    }

    function _initDpauSystem() internal {
        IDiamondPauControllerLike(DPAU_CONTROLLER).usds_setVault(ALLOCATOR_GROVE_A_VAULT);

        IAllocatorVaultLike(ALLOCATOR_GROVE_A_VAULT).rely(DPAU_PROXY);
        IAllocatorBufferLike(ALLOCATOR_GROVE_A_BUFFER).approve(Ethereum.USDS, DPAU_PROXY, type(uint256).max);
    }

    function _onboardUsdsMintBurnRateLimits() internal {
        _onboardUsdsMintBurnDpau({
            rateLimits : DPAU_RATE_LIMITS,
            mintMax    : 5_000_000e18,                   // BEFORE: 0
            mintSlope  : 5_000_000e18 / uint256(1 days), // BEFORE: 0
            burnMax    : 5_000_000e18,                   // BEFORE: 0
            burnSlope  : 5_000_000e18 / uint256(1 days)  // BEFORE: 0
        });

        // Decrease the legacy ALM mint rate limit by the amount just assigned to DPAU, so the combined
        // (ALM + DPAU) max and recharge rate stay constant. Mint/burn share one ALM key (mint decreases
        // it, burn refills it). The legacy limit currently holds 500M max / 500M-per-day slope.
        _setUSDSMintRateLimit({
            maxAmount : 495_000_000e18,                  // BEFORE: 500_000_000e18
            slope     : 495_000_000e18 / uint256(1 days) // BEFORE: 500_000_000e18/day
        });
    }

    function _onboardPsmSwapRateLimits() internal {
        _onboardPsmSwapDpau({
            rateLimits      : DPAU_RATE_LIMITS,
            usdsToUsdcMax   : 5_000_000e6,                   // BEFORE: 0
            usdsToUsdcSlope : 5_000_000e6 / uint256(1 days), // BEFORE: 0
            usdcToUsdsMax   : 5_000_000e6,                   // BEFORE: 0
            usdcToUsdsSlope : 5_000_000e6 / uint256(1 days)  // BEFORE: 0
        });

        // Decrease the legacy ALM swap rate limit by the amount just assigned to DPAU, so the combined
        // (ALM + DPAU) max and recharge rate stay constant. Both swap directions share one ALM key
        // (USDS->USDC decreases it, USDC->USDS refills it). The legacy limit currently holds 500M max / 500M-per-day slope.
        _setUSDSToUSDCRateLimit({
            maxAmount : 495_000_000e6,                  // BEFORE: 500_000_000e6
            slope     : 495_000_000e6 / uint256(1 days) // BEFORE: 500_000_000e6/day
        });
    }

    function _onboardJtrsyBasin() internal {
        _onboardBasinDpau({
            rateLimits   : DPAU_RATE_LIMITS,
            basin        : JTRSY_GROVE_BASIN,
            depositMax   : 5_000_000e18,                  // BEFORE: 0
            depositSlope : 5_000_000e18 / uint256(1 days) // BEFORE: 0
        });
    }

    function _onboardBuidlBasin() internal {
        _onboardBasinDpau({
            rateLimits   : DPAU_RATE_LIMITS,
            basin        : BUIDL_GROVE_BASIN,
            depositMax   : 5_000_000e18,                  // BEFORE: 0
            depositSlope : 5_000_000e18 / uint256(1 days) // BEFORE: 0
        });
    }

    function _swapUsdcToUsdsViaPsm() internal {
        require(IERC20Like(Ethereum.USDC).approve(Ethereum.WRAPPER_USDS_LITE_PSM_USDC_A, 1_102_056_359999));
        IUsdsPsmWrapperLike(Ethereum.WRAPPER_USDS_LITE_PSM_USDC_A).sellGem(address(this), 1_102_056_359999);
    }

    function _treasuryDistributionToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(Ethereum.GROVE_FOUNDATION, 800_000e18));
    }

}
