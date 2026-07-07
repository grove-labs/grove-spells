// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { ForeignControllerInit, ControllerInstance } from "lib/grove-alm-controller/deploy/ForeignControllerInit.sol";

import { GrovePayloadRobinhood } from "src/libraries/payloads/GrovePayloadRobinhood.sol";

/**
 * @title  July 16, 2026 Grove Robinhood Proposal
 * @author Grove Labs
 * @notice Executed on Robinhood (Arbitrum Orbit L2, chain ID 4663) via the Mainnet -> Robinhood
 *         Arbitrum-native governance relay (GroveEthereum_20260716.PAYLOAD_ROBINHOOD).
 */
contract GroveRobinhood_20260716 is GrovePayloadRobinhood {

    address internal constant ALM_PROXY       = 0x29626c2d8Ca49A51E4dECEEc5499e52983c42BD5;
    address internal constant ALM_FREEZER     = 0xB0113804960345fd0a245788b3423319c86940e5;
    // Same Relayer Safes as Ethereum.ALM_RELAYER / Ethereum.GROVE_SECONDARY_RELAYER_OPERATOR,
    // deployed deterministically to the same addresses on Robinhood (forum post, Pre-deployed contracts §5.1).
    address internal constant ALM_RELAYER     = 0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f;
    address internal constant ALM_RELAYER_2   = 0x9187807e07112359C481870feB58f0c117a29179;
    address internal constant GROVE_EXECUTOR  = 0x5ff98717a18833de1A49e11B498866d6Fa1c9296;

    address internal constant USDG                          = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant GROVE_X_STEAKHOUSE_USDG_VAULT = 0xBEEff039907422219Fb367e525954DDC092854d9;

    // Paxos-controlled USDG deposit wallet on Robinhood (Item 1c, Robinhood -> Mainnet).
    address internal constant PAXOS_USDG_DEPOSIT_WALLET = 0xfC0a7Ed7C5146B26eB38FA92c71F434A7178b06e;

    function execute() external {
        // [Robinhood] Item 1b: activate the Robinhood ForeignController (ForeignControllerInit.initAlmSystem).
        //   Forum : https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-grove-for-upcoming-spell/28024#p-106736-proposed-actions-16
        _initializeLiquidityLayer();

        // [Robinhood] Item 1c (Robinhood -> Mainnet): onboard the Paxos USDG bridge rate limit.
        //   Forum : https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-grove-for-upcoming-spell/28024#p-106736-proposed-actions-16
        _onboardPaxosUsdgBridge();

        // [Robinhood] Item 2: onboard the Grove x Steakhouse USDG Morpho vault.
        //   Forum : https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-grove-for-upcoming-spell/28024#p-106736-proposed-actions-16
        _onboardGroveXSteakhouseUsdgVault();
    }

    function _initializeLiquidityLayer() internal {
        address[] memory relayers = new address[](2);
        relayers[0] = ALM_RELAYER;
        relayers[1] = ALM_RELAYER_2;

        ForeignControllerInit.initAlmSystem(
            ControllerInstance({
                almProxy   : ALM_PROXY,
                controller : ALM_CONTROLLER,
                rateLimits : ALM_RATE_LIMITS
            }),
            ForeignControllerInit.ConfigAddressParams({
                freezer       : ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            ForeignControllerInit.CheckAddressParams({
                admin                    : GROVE_EXECUTOR,
                psm                      : address(0),
                cctp                     : address(0),
                usdc                     : address(0),
                pendleRouter             : address(0),
                uniswapV3Router          : address(0),
                uniswapV3PositionManager : address(0)
            }),
            new ForeignControllerInit.MintRecipient[](0),
            new ForeignControllerInit.LayerZeroRecipient[](0),
            new ForeignControllerInit.CentrifugeRecipient[](0)
        );
    }

    function _onboardPaxosUsdgBridge() internal {
        _onboardAssetTransfer({
            asset       : USDG,
            destination : PAXOS_USDG_DEPOSIT_WALLET,
            maxAmount   : 50_000_000e6,                   // BEFORE: 0
            slope       : 50_000_000e6 / uint256(1 days)  // BEFORE: 0
        });
    }

    function _onboardGroveXSteakhouseUsdgVault() internal {
        _onboardERC4626Vault({
            vault             : GROVE_X_STEAKHOUSE_USDG_VAULT,
            depositMax        : 50_000_000e6,                    // BEFORE: 0
            depositSlope      : 50_000_000e6 / uint256(1 days),  // BEFORE: 0
            shareUnit         : 1e18,                            // BEFORE: 0
            maxAssetsPerShare : 1.15e6                           // BEFORE: 0 (~15% headroom over the current rate of ~1.00 USDG/share)
        });
    }

}
