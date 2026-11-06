// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.34;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Base }     from "lib/grove-address-registry/src/Base.sol";
import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";
import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

contract GroveEthereum_20261119_Test is GroveTestBase {

    address internal constant NEW_AGORA_AUSD_MINT   = 0xC6A7d3662e7d38f8e3a1e991116F6c3628bd7EDf;
    address internal constant NEW_AGORA_AUSD_REDEEM = 0x9307672C95c7B92e659da63EF5ee64B0C0D14619;

    constructor() {
        id = "20261119";
    }

    function setUp() public {
        setupDomains("2026-11-04T12:32:38Z");

        deployPayloads();
    }

    function test_ETHEREUM_transfersToGroveFoundation() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 subProxyUsdsStart   = usds.balanceOf(Ethereum.GROVE_PROXY);
        uint256 foundationUsdsStart = usds.balanceOf(Ethereum.GROVE_FOUNDATION);

        assertGe(subProxyUsdsStart, 1_100_000e18, "grove-proxy-insufficient-usds-balance");

        uint256[] memory expectedAmounts = new uint256[](2);
        expectedAmounts[0] = 800_000e18;
        expectedAmounts[1] = 300_000e18;

        uint256 logsBefore = _getRecordedLogsLength();

        executeAllPayloadsAndBridges();

        _assertErc20TransferEvents({
            token           : Ethereum.USDS,
            from            : Ethereum.GROVE_PROXY,
            to              : Ethereum.GROVE_FOUNDATION,
            logsBefore      : logsBefore,
            expectedAmounts : expectedAmounts
        });

        assertEq(
            usds.balanceOf(Ethereum.GROVE_PROXY),
            subProxyUsdsStart - 1_100_000e18,
            "grove-proxy-usds-not-decreased"
        );
        assertEq(
            usds.balanceOf(Ethereum.GROVE_FOUNDATION),
            foundationUsdsStart + 1_100_000e18,
            "foundation-usds-balance-not-increased"
        );
    }

    function test_ETHEREUM_onboardNewAgoraAusdMint() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectUsdcTransferOnboarding({
            usdc                  : Ethereum.USDC,
            destination           : NEW_AGORA_AUSD_MINT,
            expectedDepositAmount : 10_000_000e6,
            depositMax            : 10_000_000e6,
            depositSlope          : 100_000_000e6 / uint256(1 days)
        });
    }

    function test_ETHEREUM_onboardNewAgoraAusdRedeem() public onChain(ChainIdUtils.Ethereum()) {
        _testDirectTokenTransferOnboarding({
            token                 : Ethereum.AUSD,
            destination           : NEW_AGORA_AUSD_REDEEM,
            expectedDepositAmount : 10_000_000e6,
            depositMax            : 10_000_000e6,
            depositSlope          : 100_000_000e6 / uint256(1 days)
        });
    }

    function test_ETHEREUM_existingAgoraAusdRateLimitsUnchanged() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 mintKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            Ethereum.AGORA_AUSD_MINT
        );
        bytes32 redeemKey = RateLimitHelpers.makeAssetDestinationKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
            Ethereum.AUSD,
            Ethereum.AGORA_AUSD_REDEEM
        );

        _assertRateLimit(mintKey,   10_000_000e6, 100_000_000e6 / uint256(1 days));
        _assertRateLimit(redeemKey, 10_000_000e6, 100_000_000e6 / uint256(1 days));

        executeAllPayloadsAndBridges();

        _assertRateLimit(mintKey,   10_000_000e6, 100_000_000e6 / uint256(1 days));
        _assertRateLimit(redeemKey, 10_000_000e6, 100_000_000e6 / uint256(1 days));
    }

    function test_ETHEREUM_raiseCctpTransferRateLimitToBase() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 generalCctpKey = MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 baseCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_BASE
        );

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(baseCctpKey, 50_000_000e6, 50_000_000e6 / uint256(1 days));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(baseCctpKey, 100_000_000e6, 100_000_000e6 / uint256(1 days));
    }

    function test_BASE_raiseCctpTransferRateLimitToEthereum() public onChain(ChainIdUtils.Base()) {
        bytes32 generalCctpKey = ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        bytes32 ethereumCctpKey = RateLimitHelpers.makeDomainKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(ethereumCctpKey, 50_000_000e6, 50_000_000e6 / uint256(1 days));

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(generalCctpKey);
        _assertRateLimit(ethereumCctpKey, 100_000_000e6, 100_000_000e6 / uint256(1 days));
    }

}
