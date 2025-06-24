// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/BloomTestBase.sol";

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { Ethereum } from "lib/bloom-address-registry/src/Ethereum.sol";

import { RateLimitHelpers } from "lib/bloom-alm-controller/src/RateLimitHelpers.sol";

import { MainnetController } from "bloom-alm-controller/src/MainnetController.sol";

import { IALMProxy }   from "bloom-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "bloom-alm-controller/src/interfaces/IRateLimits.sol";

// import { AllocatorVault }  from 'dss-allocator/src/AllocatorVault.sol';

import { BloomLiquidityLayerContext, CentrifugeConfig } from "../../test-harness/BloomLiquidityLayerTests.sol";

interface IInvestmentManager {
    function fulfillCancelDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 fulfillment
    ) external;
    function fulfillCancelRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 shares
    ) external;
    function fulfillDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
    function fulfillRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
}

interface ICentrifugeRoot {
    function endorse(address user) external;
}

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface IPSMLike {
    function kiss(address) external;
}

interface IPoolManagerLike {
    function updateTranchePrice(uint64 poolId, bytes16 trancheId, uint128 assetId, uint128 price, uint64 computedAt) external;
}

interface AutoLineLike {
    function setIlk(
        bytes32 ilk,
        uint256 line,
        uint256 gap,
        uint256 ttl
    ) external;
    function exec(bytes32) external;
}

contract BloomEthereum_20250430Test is BloomTestBase {

    address internal constant BLOOM_ETHEREUM_20250430       = 0x0c9CC5D5fF3baf096d29676039BD6fB94586111A;
    address internal constant DEPLOYER                      = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;
    address internal constant CENTRIFUGE_ROOT               = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;
    address internal constant CENTRIFUGE_INVESTMENT_MANAGER = 0x427A1ce127b1775e4Cbd4F58ad468B9F832eA7e9;
    address internal constant CENTRIFUGE_POOL_MANAGER       = 0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29;
    address internal constant CENTRIFUGE_VAULT              = 0xE9d1f733F406D4bbbDFac6D4CfCD2e13A6ee1d01;
    address internal constant CENTRIFUGE_VAULT_TOKEN        = 0x5a0F93D040De44e78F251b03c43be9CF317Dcf64;
    address internal constant MCD_IAM_AUTO_LINE             = 0xC7Bdd1F2B16447dcf3dE045C4a039A60EC2f0ba3;

    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-BLOOM-A";

    bytes16 internal constant CENTRIFUGE_VAULT_TRANCHE_ID = 0x57e1b211a9ce6306b69a414f274f9998;

    uint256 constant WAD = 10 ** 18;
    uint256 constant RAD = 10 ** 45;

    uint128 internal constant CENTRIFUGE_USDC_ASSET_ID = 242333941209166991950178742833476896417;

    uint64  internal constant CENTRIFUGE_VAULT_POOL_ID = 158696445;

    IALMProxy         almProxy   = IALMProxy(Ethereum.ALM_PROXY);
    IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

    CentrifugeConfig internal CENTRIFUGE_CONFIG = CentrifugeConfig({
        centrifugeRoot:              CENTRIFUGE_ROOT,
        centrifugeInvestmentManager: CENTRIFUGE_INVESTMENT_MANAGER,
        centrifugeTrancheId:         CENTRIFUGE_VAULT_TRANCHE_ID,
        centrifugePoolId:            CENTRIFUGE_VAULT_POOL_ID,
        centrifugeAssetId:           CENTRIFUGE_USDC_ASSET_ID
    });

    constructor() {
        id = "20250430";
    }

    function setUp() public {
        // April 23, 2025
        setupDomain({ mainnetForkBlock: 22333526 });
        spellMetadata.payload = BLOOM_ETHEREUM_20250430;

        vm.startPrank(Ethereum.PAUSE_PROXY);
        IPSMLike(address(controller.psm())).kiss(address(almProxy));
        vm.stopPrank();
    }

    function test_almSystemDeployment() public view {
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
        executePayload();

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-almProxy");

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-rateLimits");

        assertEq(controller.hasRole(controller.FREEZER(), Ethereum.ALM_FREEZER), true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), Ethereum.ALM_RELAYER), true, "incorrect-relayer-controller");

        // assertEq(AllocatorVault(Ethereum.ALLOCATOR_VAULT).wards(Ethereum.ALM_PROXY), 1, "incorrect-vault-ward");

        assertEq(IERC20(Ethereum.USDS).allowance(Ethereum.ALLOCATOR_BUFFER, Ethereum.ALM_PROXY), type(uint256).max, "incorrect-usds-allowance");
    }

    function test_basicRateLimits() public {
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
            maxAmount: 100_000_000e18,
            slope: 50_000_000e18 / uint256(1 days)
        });

        _assertRateLimit({
            key: controller.LIMIT_USDS_TO_USDC(),
            maxAmount: 100_000_000e6,
            slope: 50_000_000e6 / uint256(1 days)
        });
    }

    function test_centrifugeVaultOnboarding() public {
        _testCentrifugeOnboarding(
            CENTRIFUGE_VAULT,
            CENTRIFUGE_VAULT_TOKEN,
            CENTRIFUGE_CONFIG,
            100_000_000e6,
            100_000_000e6,
            50_000_000e6 / uint256(1 days)
        );
    }

    function test_ongoingCentrifugeDeposits() public {
        IVatLike vat = IVatLike(Ethereum.VAT);

        uint256 dailyDepositAmount = 50_000_000;
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_7540_DEPOSIT(),
            CENTRIFUGE_VAULT
        );

        vm.prank(Ethereum.PAUSE_PROXY);
        AutoLineLike(MCD_IAM_AUTO_LINE).setIlk({
            ilk:  ALLOCATOR_ILK,
            line: 2_500_000_000 * RAD,
            gap:  50_000_000 * RAD,
            ttl:  1 days
        });

        executePayload();

        AutoLineLike(MCD_IAM_AUTO_LINE).exec(ALLOCATOR_ILK);

        ( uint256 Art,,, uint256 line, ) = vat.ilks(ALLOCATOR_ILK);

        assertEq(Art,  0);
        assertEq(line, 50_000_000 * RAD);

        for (uint256 i = 0; i < 20; i++) {
            // The price of the centrifuge vault share is set to 2.0 in the test base
            assertEq(IERC20(CENTRIFUGE_VAULT_TOKEN).balanceOf(Ethereum.ALM_PROXY), (dailyDepositAmount * 1e6 / 2) * i);

            (Art,,, line, ) = vat.ilks(ALLOCATOR_ILK);
            assertEq(Art, (dailyDepositAmount * WAD) * i);

            assertEq(rateLimits.getCurrentRateLimit(depositKey), 100_000_000e6);

            AutoLineLike(MCD_IAM_AUTO_LINE).exec(ALLOCATOR_ILK);
            _centrifugeDeposit(dailyDepositAmount * 1e6);

            // The price of the centrifuge vault share is set to 2.0 in the test base
            assertEq(IERC20(CENTRIFUGE_VAULT_TOKEN).balanceOf(Ethereum.ALM_PROXY), (dailyDepositAmount * 1e6 / 2) * (i + 1));

            (Art,,, line, ) = vat.ilks(ALLOCATOR_ILK);
            assertEq(Art,  (dailyDepositAmount * WAD) * (i + 1));
            assertEq(line, (dailyDepositAmount * RAD) * (i + 1));

            assertEq(rateLimits.getCurrentRateLimit(depositKey), 50_000_000e6);

            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 days + 1);
        }

        AutoLineLike(MCD_IAM_AUTO_LINE).exec(ALLOCATOR_ILK);

        (Art,,, line, ) = vat.ilks(ALLOCATOR_ILK);
        assertEq(Art,  1_000_000_000 * WAD);
        assertEq(line, 1_050_000_000 * RAD);

        // The price of the centrifuge vault share is set to 2.0 in the test base
        assertEq(IERC20(CENTRIFUGE_VAULT_TOKEN).balanceOf(Ethereum.ALM_PROXY), 1_000_000_000 / 2 * 1e6);
    }

    function _centrifugeDeposit(uint256 depositAmount) internal {
        vm.startPrank(Ethereum.ALM_RELAYER);
        controller.mintUSDS(depositAmount * 1e12);
        controller.swapUSDSToUSDC(depositAmount);
        controller.requestDepositERC7540(CENTRIFUGE_VAULT, depositAmount);
        vm.stopPrank();

        _centrifugeFulfillDepositRequest(
            CENTRIFUGE_CONFIG,
            depositAmount
        );

        vm.prank(Ethereum.ALM_RELAYER);
        controller.claimDepositERC7540(CENTRIFUGE_VAULT);
    }

}
