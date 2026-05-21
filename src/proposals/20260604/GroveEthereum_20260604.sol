// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { IALMProxy } from "grove-alm-controller/src/interfaces/IALMProxy.sol";

import { GrovePayloadEthereum } from "src/libraries/payloads/GrovePayloadEthereum.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IAccessControlLike {
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
}

interface IUsdsPsmWrapperLike {
    function sellGem(address usr, uint256 gemAmt) external returns (uint256 usdsOut);
}

interface IGroveBasinLike {
    function deposit(address asset, address receiver, uint256 assetsToDeposit) external returns (uint256 shares);
}

interface IAllocatorVaultLike {
    function draw(uint256 wad) external;
}

/**
 * @title  June 4, 2026 Grove Ethereum Proposal
 * @author Grove Labs
 */
contract GroveEthereum_20260604 is GrovePayloadEthereum {

    address internal constant WRAPPER_USDS_LITE_PSM_USDC_A = 0xA188EEC8F81263234dA3622A406892F3D630f98c;

    address internal constant JTRSY_GROVE_BASIN = 0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363;
    address internal constant BUIDL_GROVE_BASIN = 0x10b3d3A96646720f8B3a29229cF96d513f3C84F1;

    function _execute() internal override {
        // [Ethereum] Grove Treasury — Monthly Grant for Grove Foundation (Months 2 + 3 combined)
        //   Forum : TODO
        _transferMonthlyGrantToGroveFoundation();

        // [Ethereum] Transfer GROVE Tokens to Grove Foundation
        //   Forum : TODO
        _transferGroveTokensToGroveFoundation();

        // [Ethereum] Swap USDC to USDS in Grove SubProxy
        //   Forum : TODO
        _swapUsdcToUsdsViaPsm();

        // [Ethereum] Onboard JTRSY Grove Basin — Initial Deposit (50M USDS)
        //   Forum : TODO
        _depositInitialUsdsToJtrsyGroveBasin();

        // [Ethereum] Onboard BUIDL Grove Basin — Initial Deposit (50M USDS)
        //   Forum : TODO
        _depositInitialUsdsToBuidlGroveBasin();
    }

    function _transferMonthlyGrantToGroveFoundation() internal {
        require(IERC20Like(Ethereum.USDS).transfer(Ethereum.GROVE_FOUNDATION, 1_600_000e18));
    }

    function _transferGroveTokensToGroveFoundation() internal {
        require(IERC20Like(Ethereum.GROVE_TOKEN).transfer(Ethereum.GROVE_FOUNDATION, 500_000_000e18));
    }

    function _swapUsdcToUsdsViaPsm() internal {
        require(IERC20Like(Ethereum.USDC).approve(WRAPPER_USDS_LITE_PSM_USDC_A, 753_649e6));
        IUsdsPsmWrapperLike(WRAPPER_USDS_LITE_PSM_USDC_A).sellGem(address(this), 753_649e6);
    }

    function _depositInitialUsdsToJtrsyGroveBasin() internal {
        _depositInitialUsdsToGroveBasin(JTRSY_GROVE_BASIN, 50_000_000e18);
    }

    function _depositInitialUsdsToBuidlGroveBasin() internal {
        _depositInitialUsdsToGroveBasin(BUIDL_GROVE_BASIN, 50_000_000e18);
    }

    function _depositInitialUsdsToGroveBasin(address basin, uint256 amount) internal {
        IALMProxy almProxy = IALMProxy(Ethereum.ALM_PROXY);
        bytes32 controllerRole = almProxy.CONTROLLER();

        IAccessControlLike(Ethereum.ALM_PROXY).grantRole(controllerRole, address(this));

        almProxy.doCall(
            Ethereum.ALLOCATOR_VAULT,
            abi.encodeCall(IAllocatorVaultLike.draw, (amount))
        );
        almProxy.doCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (Ethereum.ALLOCATOR_BUFFER, Ethereum.ALM_PROXY, amount))
        );
        almProxy.doCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.approve, (basin, amount))
        );
        almProxy.doCall(
            basin,
            abi.encodeCall(IGroveBasinLike.deposit, (Ethereum.USDS, Ethereum.ALM_PROXY, amount))
        );

        IAccessControlLike(Ethereum.ALM_PROXY).revokeRole(controllerRole, address(this));
    }

}
