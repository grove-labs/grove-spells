// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";

import { IExecutor } from "lib/grove-gov-relay/src/interfaces/IExecutor.sol";

import { LZForwarder } from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";
import { LZReceiver }  from "lib/xchain-helpers/src/receivers/LZReceiver.sol";

import { UlnConfig }      from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import { ExecutorConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

import { ChainIdUtils }  from "src/libraries/helpers/ChainId.sol";
import { CastingHelpers } from "src/libraries/helpers/CastingHelpers.sol";

import { GroveTestBase } from "src/test-harness/GroveTestBase.sol";

interface ILayerZeroEndpointV2Like {
    function getReceiveLibrary(address receiver, uint32 srcEid) external view returns (address lib, bool isDefault);
    function getSendLibrary(address sender, uint32 dstEid) external view returns (address lib);
    function getConfig(address oapp, address lib, uint32 eid, uint32 configType) external view returns (bytes memory config);
}

contract GroveEthereum_20260507_Test is GroveTestBase {

    address internal constant GROVE_X_STEAKHOUSE_RLUSD_V2 = 0xBeEff4fD39F8e48b6a6e475445D650cb11e9599F;

    address internal constant GROVE_FOUNDATION = 0xE3EC4CC359E68c9dCE15Bf667b1aD37Df54a5a42;

    uint256 internal constant GROVE_FOUNDATION_GRANT_AMOUNT = 800_000e18;

    address internal constant AVALANCHE_OLD_CCTP_RECEIVER = 0x26e9512547feC1906C55256e491DfB6673D8C23f;
    address internal constant AVALANCHE_NEW_LZ_RECEIVER   = 0x380Be2b91B63BF75B194913b6e2C07Df09598c22;

    constructor() {
        id = "20260507";
    }

    function setUp() public {
        setupDomains("2026-04-22T10:00:00Z");

        // Execute prior (20260423) payloads as dependencies for this spell
        chainData[ChainIdUtils.Avalanche()].newController = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;

        chainData[ChainIdUtils.Ethereum()].payload  = 0x76Ba24676e1055D3E6b160086f0bc9BaffF76929;
        chainData[ChainIdUtils.Avalanche()].payload = 0x1204f2C342706cE6B75997c89619D130Ee9dDa2c;
        executeAllPayloadsAndBridges();

        // After 20260423 upgraded the Avalanche controller, update prev/new to the post-upgrade address
        chainData[ChainIdUtils.Avalanche()].prevController = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;
        chainData[ChainIdUtils.Avalanche()].newController  = 0x4236B772BEeEAFF57550Aa392A0f227C0b908Ce7;

        deployPayloads();
    }

    function test_ETHEREUM_onboardGroveXSteakhouseRlusdMorphoVaultV2() public onChain(ChainIdUtils.Ethereum()) {
        _testERC4626Onboarding({
            vault                 : GROVE_X_STEAKHOUSE_RLUSD_V2,
            expectedDepositAmount : 100_000_000e18,
            depositMax            : 100_000_000e18,
            depositSlope          : 100_000_000e18 / uint256(1 days),
            shareUnit             : 1e18,
            maxAssetsPerShare     : 3e18
        });
    }

    function test_ETHEREUM_transferMonthlyGrantToGroveFoundation() public onChain(ChainIdUtils.Ethereum()) {
        IERC20 usds = IERC20(Ethereum.USDS);

        uint256 foundationBalanceBefore = usds.balanceOf(GROVE_FOUNDATION);
        uint256 groveProxyBalanceBefore = usds.balanceOf(Ethereum.GROVE_PROXY);

        assertGe(
            groveProxyBalanceBefore,
            GROVE_FOUNDATION_GRANT_AMOUNT,
            "grove-proxy-insufficient-balance"
        );

        executeAllPayloadsAndBridges();

        uint256 foundationBalanceAfter = usds.balanceOf(GROVE_FOUNDATION);
        uint256 groveProxyBalanceAfter = usds.balanceOf(Ethereum.GROVE_PROXY);

        assertEq(
            foundationBalanceAfter,
            foundationBalanceBefore + GROVE_FOUNDATION_GRANT_AMOUNT,
            "foundation-balance-not-increased"
        );

        assertEq(
            groveProxyBalanceAfter,
            groveProxyBalanceBefore - GROVE_FOUNDATION_GRANT_AMOUNT,
            "grove-proxy-balance-not-decreased"
        );
    }

    function test_AVALANCHE_upgradeGovernanceRelayToLayerZeroV2() public onChain(ChainIdUtils.Avalanche()) {
        IExecutor  executor   = IExecutor(Avalanche.GROVE_EXECUTOR);
        LZReceiver lzReceiver = LZReceiver(AVALANCHE_NEW_LZ_RECEIVER);

        bytes32    submissionRole = executor.SUBMISSION_ROLE();

        _verifyLayerZeroReceiverDeployment({
            _executor : Avalanche.GROVE_EXECUTOR,
            _receiver : AVALANCHE_NEW_LZ_RECEIVER
        });

        // Peer must be wired to the Ethereum Grove Proxy for srcEid = ENDPOINT_ID_ETHEREUM
        assertEq(
            lzReceiver.peers(LZForwarder.ENDPOINT_ID_ETHEREUM),
            CastingHelpers.addressToLayerZeroRecipient(Ethereum.GROVE_PROXY),
            "incorrect-peer"
        );

        // ULN (security stack) config must use the Nethermind + LayerZero DVNs for Avalanche
        {
            ILayerZeroEndpointV2Like lzEndpoint =
                ILayerZeroEndpointV2Like(address(lzReceiver.endpoint()));

            (address receiveLib, ) = lzEndpoint.getReceiveLibrary(AVALANCHE_NEW_LZ_RECEIVER, LZForwarder.ENDPOINT_ID_ETHEREUM);
            assertEq(receiveLib, LZForwarder.RECEIVE_LIBRARY_AVALANCHE, "incorrect-receive-library");

            UlnConfig memory cfg = abi.decode(
                lzEndpoint.getConfig({
                    oapp       : AVALANCHE_NEW_LZ_RECEIVER,
                    lib        : receiveLib,
                    eid        : LZForwarder.ENDPOINT_ID_ETHEREUM,
                    configType : 2
                }),
                (UlnConfig)
            );

            assertEq(uint256(cfg.confirmations),        15, "incorrect-confirmations");
            assertEq(uint256(cfg.requiredDVNCount),     2,  "incorrect-required-dvn-count");
            assertEq(uint256(cfg.optionalDVNCount),     0,  "incorrect-optional-dvn-count");
            assertEq(uint256(cfg.optionalDVNThreshold), 0,  "incorrect-optional-dvn-threshold");

            // 0x962F… (LZ) < 0xa59B… (Nethermind) on Avalanche
            assertEq(cfg.requiredDVNs[0], LZForwarder.LAYER_ZERO_DVN_AVALANCHE, "incorrect-required-dvn-0");
            assertEq(cfg.requiredDVNs[1], LZForwarder.NETHERMIND_DVN_AVALANCHE,  "incorrect-required-dvn-1");
        }

        assertTrue (executor.hasRole(submissionRole, AVALANCHE_OLD_CCTP_RECEIVER));
        assertFalse(executor.hasRole(submissionRole, AVALANCHE_NEW_LZ_RECEIVER));

        executeAllPayloadsAndBridges();

        assertTrue(executor.hasRole(submissionRole, AVALANCHE_OLD_CCTP_RECEIVER));
        assertTrue(executor.hasRole(submissionRole, AVALANCHE_NEW_LZ_RECEIVER));
    }

    function test_ETHEREUM_configureLZGovernanceSender() public onChain(ChainIdUtils.Ethereum()) {
        ILayerZeroEndpointV2Like endpoint =
            ILayerZeroEndpointV2Like(LZForwarder.ENDPOINT_ETHEREUM);

        address sender = Ethereum.GROVE_PROXY;
        uint32  dstEid = LZForwarder.ENDPOINT_ID_AVALANCHE;

        executeAllPayloadsAndBridges();

        // --- Send library ---
        address sendLib = endpoint.getSendLibrary(sender, dstEid);
        assertTrue(sendLib != address(0), "send-library-not-configured");

        // --- Executor config (configType = 1) ---
        ExecutorConfig memory execCfg = abi.decode(
            endpoint.getConfig({
                oapp       : sender,
                lib        : sendLib,
                eid        : dstEid,
                configType : 1
            }),
            (ExecutorConfig)
        );

        assertEq(execCfg.executor, LZForwarder.EXECUTOR_ETHEREUM, "incorrect-sender-executor");
        assertGt(execCfg.maxMessageSize, 0, "sender-max-message-size-zero");

        // --- ULN config (configType = 2) ---
        UlnConfig memory ulnCfg = abi.decode(
            endpoint.getConfig({
                oapp       : sender,
                lib        : sendLib,
                eid        : dstEid,
                configType : 2
            }),
            (UlnConfig)
        );

        assertEq(uint256(ulnCfg.confirmations), 15, "incorrect-sender-confirmations");
        assertEq(uint256(ulnCfg.requiredDVNCount), 2, "incorrect-sender-required-dvn-count");

        // 0x589d… (LZ) < 0xa59B… (Nethermind) on Ethereum
        assertEq(ulnCfg.requiredDVNs[0], LZForwarder.LAYER_ZERO_DVN_ETHEREUM, "incorrect-sender-required-dvn-0");
        assertEq(ulnCfg.requiredDVNs[1], LZForwarder.NETHERMIND_DVN_ETHEREUM,  "incorrect-sender-required-dvn-1");
    }

}
