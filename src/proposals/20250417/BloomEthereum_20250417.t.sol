// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/BloomTestBase.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/bloom-address-registry/src/Ethereum.sol";

import { RateLimitHelpers } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

import { MainnetController } from "bloom-alm-controller/src/MainnetController.sol";

import { IALMProxy }   from "bloom-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "bloom-alm-controller/src/interfaces/IRateLimits.sol";

import { AllocatorVault }  from 'dss-allocator/src/AllocatorVault.sol';

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

contract BloomEthereum_20250320Test is BloomTestBase {

    // TODO: Confirm these addresses
    address internal constant FREEZER                 = 0x90D8c80C028B4C09C0d8dcAab9bbB057F0513431;
    address internal constant RELAYER                 = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;
    address internal constant DEPLOYER                = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;
    address internal constant MORPHO_STEAKHOUSE_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-BLOOM-A";

    IALMProxy         almProxy   = IALMProxy(Ethereum.ALM_PROXY);
    IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

    constructor() {
        id = "20250417";
    }

    function setUp() public {
        // April 02, 2025
        setupDomain({ mainnetForkBlock: 22182140 });
        deployPayload()
    }

    function test_almSystemDeployment() public {
        vm.skip(true);

        assertEq(almProxy.hasRole(0x0, Ethereum.BLOOM_PROXY),   true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Ethereum.BLOOM_PROXY), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Ethereum.BLOOM_PROXY), true, "incorrect-admin-controller");

        assertEq(almProxy.hasRole(0x0, DEPLOYER),   false, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, DEPLOYER), false, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, DEPLOYER), false, "incorrect-admin-controller");

        assertEq(address(controller.proxy()),                Ethereum.ALM_PROXY,            "incorrect-almProxy");
        assertEq(address(controller.rateLimits()),           Ethereum.ALM_RATE_LIMITS,      "incorrect-rateLimits");
        assertEq(address(controller.vault()),                Ethereum.ALLOCATOR_VAULT,      "incorrect-vault");
        assertEq(address(controller.buffer()),               Ethereum.ALLOCATOR_BUFFER,     "incorrect-buffer");
        assertEq(address(controller.psm()),                  Ethereum.PSM,                  "incorrect-psm");
        assertEq(address(controller.daiUsds()),              Ethereum.DAI_USDS,             "incorrect-daiUsds");
        assertEq(address(controller.cctp()),                 Ethereum.CCTP_TOKEN_MESSENGER, "incorrect-cctpMessenger");
        assertEq(address(controller.dai()),                  Ethereum.DAI,                  "incorrect-dai");
        assertEq(address(controller.susde()),                Ethereum.SUSDE,                "incorrect-susde");
        assertEq(address(controller.ustb()),                 Ethereum.USTB,                 "incorrect-ustb");
        assertEq(address(controller.usdc()),                 Ethereum.USDC,                 "incorrect-usdc");
        assertEq(address(controller.usde()),                 Ethereum.USDE,                 "incorrect-usde");
        assertEq(address(controller.usds()),                 Ethereum.USDS,                 "incorrect-usds");
        assertEq(address(controller.buidlRedeem()),          Ethereum.BUIDL_REDEEM,          "incorrect-buidlRedeem");
        assertEq(address(controller.ethenaMinter()),         Ethereum.ETHENA_MINTER,         "incorrect-ethenaMinter");
        assertEq(address(controller.superstateRedemption()), Ethereum.SUPERSTATE_REDEMPTION, "incorrect-superstateRedemption");

        assertEq(controller.psmTo18ConversionFactor(), 1e12, "incorrect-psmTo18ConversionFactor");

        IVatLike vat = IVatLike(Ethereum.VAT);

        ( uint256 Art, uint256 rate,, uint256 line, ) = vat.ilks(ALLOCATOR_ILK);

        assertEq(Art,  0);
        assertEq(rate, 1e27);
        assertEq(line, 10_000_000e45);

        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.BLOOM_PROXY),  0);
    }

    function test_almSystemInitialization() public {
        vm.skip(true);

        executePayload();

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-almProxy");

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-rateLimits");

        assertEq(controller.hasRole(controller.FREEZER(), FREEZER), true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), RELAYER), true, "incorrect-relayer-controller");

        assertEq(AllocatorVault(Ethereum.ALLOCATOR_VAULT).wards(Ethereum.ALM_PROXY), 1, "incorrect-vault-ward");

        assertEq(IERC20(Ethereum.USDS).allowance(Ethereum.ALLOCATOR_BUFFER, Ethereum.ALM_PROXY), type(uint256).max, "incorrect-usds-allowance");
    }

    function test_basicRateLimits() public {
        vm.skip(true);

        _assertRateLimit({
            key: controller.LIMIT_USDS_MINT(),
            maxAmount: 0,
            slope: 0
        });

        _assertRateLimit({
            key: controller.LIMIT_USDS_TO_USDC(),
            maxAmount: 0,
            slope: 0
        });

        executePayload();

        _assertRateLimit({
            key: controller.LIMIT_USDS_MINT(),
            maxAmount: 100_000_000e6,              // TODO: get actual number
            slope: 100_000_000e6 / uint256(1 days) // TODO: get actual number
        });

        _assertRateLimit({
            key: controller.LIMIT_USDS_TO_USDC(),
            maxAmount: 100_000_000e6,              // TODO: get actual number
            slope: 100_000_000e6 / uint256(1 days) // TODO: get actual number
        });
    }

    function test_morphoSteakhouseVaultOnboarding() public {
        vm.skip(true);

        _testERC4626Onboarding(
            MORPHO_STEAKHOUSE_VAULT,
            100_000_000e6,                  // TODO: get actual number
            100_000_000e6,                  // TODO: get actual number
            100_000_000e6 / uint256(1 days) // TODO: get actual number
        );
    }

    // TODO: Add an integration test for the Bloom Liquidity Layer (perform operations intended after spell execution)
}
