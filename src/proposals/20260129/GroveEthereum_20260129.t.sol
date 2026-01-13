
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { console } from "forge-std/console.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";
import { Base }     from "lib/grove-address-registry/src/Base.sol";

// import { MainnetController } from "lib/grove-alm-controller/src/MainnetController.sol";
// import { ForeignController } from "lib/grove-alm-controller/src/ForeignController.sol";
// import { RateLimitHelpers }  from "lib/grove-alm-controller/src/RateLimitHelpers.sol";

// import { CCTPv2Forwarder } from "lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol";

// import { CastingHelpers }        from "src/libraries/helpers/CastingHelpers.sol";
import { ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

// import { GroveLiquidityLayerContext } from "src/test-harness/CommonTestBase.sol";
import { GroveTestBase }              from "src/test-harness/GroveTestBase.sol";

interface IStarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
    function exec() external returns (address);
}

interface IExecutorLike {
    function executeDelegateCall(address target, bytes memory data) external;
}

contract GroveEthereum_20260129_Test is GroveTestBase {

    address internal constant ETHEREUM_20260115_PAYLOAD = 0x90230A17dcA6c0b126521BB55B98f8C6Cf2bA748;
    address internal constant BASE_20260115_PAYLOAD     = 0xAe9EAd94B00d137f01159A7F279c0b78dd04c860;

    bytes32 internal constant ETHEREUM_20260115_CODEHASH = 0x9317fd876201f5a1b08658b47a47c8980b8c8aa7538e059408668b502acfa5fb;

    constructor() {
        id = "20260129";
    }

    function setUp() public {
        setupDomains("2026-01-09T16:05:00Z");

        _executePreviousMainnetSpell();
        _executePreviousBaseSpell();

        deployPayloads();
    }

    function _executePreviousMainnetSpell() public onChain(ChainIdUtils.Ethereum()) {
        vm.prank(Ethereum.PAUSE_PROXY);
        IStarGuardLike(Ethereum.GROVE_STAR_GUARD).plot({
            addr_ : ETHEREUM_20260115_PAYLOAD,
            tag_  : ETHEREUM_20260115_CODEHASH
        });

        address returnedPayloadAddress = IStarGuardLike(Ethereum.GROVE_STAR_GUARD).exec();
        require(ETHEREUM_20260115_PAYLOAD == returnedPayloadAddress, "FAILED TO EXECUTE PAYLOAD");
    }

    function _executePreviousBaseSpell() public onChain(ChainIdUtils.Base()) {
        vm.prank(Base.GROVE_EXECUTOR);
        IExecutorLike(Base.GROVE_EXECUTOR).executeDelegateCall(
            BASE_20260115_PAYLOAD,
            abi.encodeWithSignature('execute()')
        );
    }

    function test_ETHEREUM_reOnboardAgoraAusdMintRedeem() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardCurveAusdUsdcSwaps() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardCurveAusdUsdcLp() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardUniswapV3AusdUsdcSwaps() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardUniswapV3AusdUsdcLp() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardCurvePyusdUsdsSwaps() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardGroveXSteakhouseUsdcMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardSteakhousePyusdMorphoVault() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

    function test_ETHEREUM_onboardRelayers() public onChain(ChainIdUtils.Ethereum()) {
        vm.skip(true);
        // TODO: Implement
    }

}
