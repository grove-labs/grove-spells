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

interface IRestrictionManager {
    function updateMember(address token, address user, uint64 validUntil) external;
}

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface IPSMLike {
    function kiss(address) external;
}

contract BloomEthereum_20250501Test is BloomTestBase {

    address internal constant DEPLOYER = 0xB51e492569BAf6C495fDa00F94d4a23ac6c48F12;

    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-BLOOM-A";

    address internal constant CENTRIFUGE_ROOT                = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;
    address internal constant CENTRIFUGE_INVESTMENT_MANAGER  = 0x427A1ce127b1775e4Cbd4F58ad468B9F832eA7e9;
    address internal constant CENTRIFUGE_RESTRICTION_MANAGER = 0x4737C3f62Cc265e786b280153fC666cEA2fBc0c0;

    uint128 internal constant CENTRIFUGE_USDC_ASSET_ID = 242333941209166991950178742833476896417;

    address internal constant CENTRIFUGE_JAAA_VAULT  = 0xdEADBEeF00000000000000000000000000000000; // TODO: add address
    address internal constant CENTRIFUGE_JTRSY_VAULT = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;
    address internal constant CENTRIFUGE_JAAA_TOKEN  = 0xdEADBEeF00000000000000000000000000000000; // TODO: add address
    address internal constant CENTRIFUGE_JTRSY_TOKEN = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;

    uint64  internal constant CENTRIFUGE_JAAA_POOL_ID  = 4139607887; // TODO: Change to proper ID
    uint64  internal constant CENTRIFUGE_JTRSY_POOL_ID = 4139607887;

    bytes16 internal constant CENTRIFUGE_JAAA_TRANCHE_ID  = 0x97aa65f23e7be09fcd62d0554d2e9273; // TODO: Change to proper ID
    bytes16 internal constant CENTRIFUGE_JTRSY_TRANCHE_ID = 0x97aa65f23e7be09fcd62d0554d2e9273;



    IALMProxy         almProxy   = IALMProxy(Ethereum.ALM_PROXY);
    IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

    constructor() {
        id = "20250501";
    }

    function setUp() public {
        // April 17, 2025
        setupDomain({ mainnetForkBlock: 22288130 });
        deployPayload();

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

        assertEq(AllocatorVault(Ethereum.ALLOCATOR_VAULT).wards(Ethereum.ALM_PROXY), 1, "incorrect-vault-ward");

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
            maxAmount: 100_000e18,
            slope: 50_000e18 / uint256(1 days)
        });

        _assertRateLimit({
            key: controller.LIMIT_USDS_TO_USDC(),
            maxAmount: 100_000e6,
            slope: 50_000e6 / uint256(1 days)
        });
    }

    function test_centrifugeJAAAOnboarding() public {
        vm.skip(true); // TODO: Un-skip once JAAA values are confirmed
        _testCentrifugeOnboarding(
            CENTRIFUGE_JAAA_VAULT,
            CENTRIFUGE_JAAA_TOKEN,
            CentrifugeConfig({
                centrifugeRoot:               CENTRIFUGE_ROOT,
                centrifugeInvestmentManager:  CENTRIFUGE_INVESTMENT_MANAGER,
                centrifugeTrancheId:          CENTRIFUGE_JAAA_TRANCHE_ID,
                centrifugePoolId:             CENTRIFUGE_JAAA_POOL_ID,
                centrifugeAssetId:            CENTRIFUGE_USDC_ASSET_ID
            }),
            100_000_000e6,
            100_000_000e6,
            10_000_000e6 / uint256(1 days)
        );
    }

    function test_centrifugeJTRSYOnboarding() public {
        _testCentrifugeOnboarding(
            CENTRIFUGE_JTRSY_VAULT,
            CENTRIFUGE_JTRSY_TOKEN,
            CentrifugeConfig({
                centrifugeRoot:               CENTRIFUGE_ROOT,
                centrifugeInvestmentManager:  CENTRIFUGE_INVESTMENT_MANAGER,
                centrifugeTrancheId:          CENTRIFUGE_JTRSY_TRANCHE_ID,
                centrifugePoolId:             CENTRIFUGE_JTRSY_POOL_ID,
                centrifugeAssetId:            CENTRIFUGE_USDC_ASSET_ID
            }),
            100_000e6,
            100_000e6,
            50_000e6 / uint256(1 days)
        );
    }

}
