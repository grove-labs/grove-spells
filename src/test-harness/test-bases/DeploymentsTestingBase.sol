// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Avalanche } from "grove-address-registry/Avalanche.sol";
import { Ethereum }  from "grove-address-registry/Ethereum.sol";
import { Plume }     from "grove-address-registry/Plume.sol";
import { Base }      from "grove-address-registry/Base.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { LZForwarder }   from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { ForeignController } from "grove-alm-controller/src/ForeignController.sol";
import { MainnetController } from "grove-alm-controller/src/MainnetController.sol";

import { IRateLimits } from "grove-alm-controller/src/interfaces/IRateLimits.sol";
import { IALMProxy }   from "grove-alm-controller/src/interfaces/IALMProxy.sol";

import { Executor } from "grove-gov-relay/src/Executor.sol";

import { ArbitrumReceiver } from "lib/xchain-helpers/src/receivers/ArbitrumReceiver.sol";
import { CCTPReceiver }     from "lib/xchain-helpers/src/receivers/CCTPReceiver.sol";
import { LZReceiver }       from "lib/xchain-helpers/src/receivers/LZReceiver.sol";
import { OptimismReceiver } from "lib/xchain-helpers/src/receivers/OptimismReceiver.sol";

import { CastingHelpers }             from "src/libraries/helpers/CastingHelpers.sol";
import { ChainId, ChainIdUtils }      from "src/libraries/helpers/ChainId.sol";
import { GroveLiquidityLayerHelpers } from "src/libraries/helpers/GroveLiquidityLayerHelpers.sol";

import { GroveLiquidityLayerContext, CommonTestBase } from "../CommonTestBase.sol";

interface ILayerZeroEndpointV2 {
    function delegates(address sender) external view returns (address);
}

abstract contract DeploymentsTestingBase is CommonTestBase {

    struct AlmSystemContracts {
        address admin;
        address proxy;
        address rateLimits;
        address controller;
    }

    struct AlmSystemActors {
        address deployer;
        address freezer;
        address relayer;
    }

    struct ForeignAlmSystemDependencies {
        address psm;
        address usdc;
        address cctp;
    }

    struct MainnetAlmSystemDependencies {
        address vault;
        address psm;
        address daiUsds;
        address cctp;
    }

    function _verifyMainnetControllerDeployment(
        AlmSystemContracts memory contracts,
        AlmSystemActors memory actors,
        MainnetAlmSystemDependencies memory dependencies
    ) internal view {
        MainnetController controller = MainnetController(contracts.controller);

        // All contracts have admin as admin set in constructor
        assertEq(controller.hasRole(0x0, contracts.admin), true, "incorrect-admin-controller");

        // No roles other than admin as admin are set before the initialization (checking for EOA and multisig wallets)
        assertEq(controller.hasRole(0x0,                  actors.deployer), false, "incorrect-admin-controller");
        assertEq(controller.hasRole(0x0,                  actors.relayer),  false, "incorrect-admin-controller");
        assertEq(controller.hasRole(0x0,                  actors.freezer),  false, "incorrect-admin-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.deployer), false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.freezer),  false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.relayer),  false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.deployer), false, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.freezer),  false, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.relayer),  false, "incorrect-relayer-controller");

        // Controller has correct proxy, rate limits, psm, usdc, and cctp messenger
        assertEq(address(controller.proxy()),      contracts.proxy,      "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), contracts.rateLimits, "incorrect-rateLimits");
        assertEq(address(controller.vault()),      dependencies.vault,   "incorrect-vault");
        assertEq(address(controller.psm()),        dependencies.psm,     "incorrect-psm");
        assertEq(address(controller.daiUsds()),    dependencies.daiUsds, "incorrect-daiUsds");
        assertEq(address(controller.cctp()),       dependencies.cctp,    "incorrect-cctp");
    }

    function _verifyForeignControllerDeployment(
        AlmSystemContracts           memory contracts,
        AlmSystemActors              memory actors,
        ForeignAlmSystemDependencies memory dependencies
    ) internal view {
        ForeignController controller = ForeignController(contracts.controller);

        // All contracts have admin as admin set in constructor
        assertEq(controller.hasRole(0x0, contracts.admin), true, "incorrect-admin-controller");

        // No roles other than admin as admin are set before the initialization (checking for EOA and multisig wallets)
        assertEq(controller.hasRole(0x0,                  actors.deployer), false, "incorrect-admin-controller");
        assertEq(controller.hasRole(0x0,                  actors.relayer),  false, "incorrect-admin-controller");
        assertEq(controller.hasRole(0x0,                  actors.freezer),  false, "incorrect-admin-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.deployer), false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.freezer),  false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.relayer),  false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.deployer), false, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.freezer),  false, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.relayer),  false, "incorrect-relayer-controller");

        // Controller has correct proxy, rate limits, psm, usdc, and cctp messenger
        assertEq(address(controller.proxy()),      contracts.proxy,      "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), contracts.rateLimits, "incorrect-rateLimits");
        assertEq(address(controller.psm()),        dependencies.psm,     "incorrect-psm");
        assertEq(address(controller.usdc()),       dependencies.usdc,    "incorrect-usdc");
        assertEq(address(controller.cctp()),       dependencies.cctp,    "incorrect-cctp");
    }

    function _verifyForeignAlmSystemDeployment(
        AlmSystemContracts           memory contracts,
        AlmSystemActors              memory actors,
        ForeignAlmSystemDependencies memory dependencies
    ) internal view {
        IALMProxy   almProxy   = IALMProxy(contracts.proxy);
        IRateLimits rateLimits = IRateLimits(contracts.rateLimits);

        // All contracts have admin as admin set in constructor
        assertEq(almProxy.hasRole(0x0,   contracts.admin), true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, contracts.admin), true, "incorrect-admin-rateLimits");

        // No roles other than admin as admin are set before the initialization in the proxy
        assertEq(almProxy.hasRole(0x0,                   actors.deployer),      false, "incorrect-admin-almProxy");
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), actors.deployer),      false, "incorrect-controller-almProxy");
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), contracts.controller), false, "incorrect-controller-almProxy");

        // No roles other than admin as admin are set before the initialization in the rate limits
        assertEq(rateLimits.hasRole(0x0,                     actors.deployer),      false, "incorrect-admin-rateLimits");
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), actors.deployer),      false, "incorrect-controller-rateLimits");
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), contracts.controller), false, "incorrect-controller-rateLimits");

        _verifyForeignControllerDeployment(contracts, actors, dependencies);
    }

    function _verifyForeignDomainExecutorDeployment(
        address _executor,
        address _receiver,
        address _deployer
    ) internal view {
        Executor executor = Executor(_executor);

        // Executor has correct delay and grace period to default values
        assertEq(executor.delay(),       0,      "incorrect-executor-delay");
        assertEq(executor.gracePeriod(), 7 days, "incorrect-executor-grace-period");

        // Executor has not processed any actions sets
        assertEq(executor.actionsSetCount(), 0, "incorrect-executor-actions-set-count");

        // Executor is its own admin
        assertEq(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), _executor), true, "incorrect-default-admin-role-executor");

        // Executor has no roles assigned to the deployer
        assertEq(executor.hasRole(executor.SUBMISSION_ROLE(),    _deployer), false, "incorrect-submission-role-executor");
        assertEq(executor.hasRole(executor.GUARDIAN_ROLE(),      _deployer), false, "incorrect-guardian-role-executor");
        assertEq(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), _deployer), false, "incorrect-default-admin-role-executor");

        // Submissions role is correctly set to the crosschain receiver
        assertEq(executor.hasRole(executor.SUBMISSION_ROLE(), _receiver), true, "incorrect-submission-role-executor");
    }

    function _verifyCctpReceiverDeployment(
        address _executor,
        address _receiver,
        address _cctpMessageTransmitter
    ) internal view {
        CCTPReceiver receiver = CCTPReceiver(_receiver);

        // Receiver's destination messenger has to be the local cctp messenger
        assertEq(receiver.destinationMessenger(), _cctpMessageTransmitter, "incorrect-cctp-transmitter");

        // Source domain id has to be always Ethereum Mainnet id
        assertEq(receiver.sourceDomainId(), 0, "incorrect-source-domain-id");

        // Source authority has to be the Ethereum Mainnet Grove Proxy
        assertEq(receiver.sourceAuthority(), CastingHelpers.addressToCctpRecipient(Ethereum.GROVE_PROXY), "incorrect-source-authority");

        // Target has to be the executor
        assertEq(receiver.target(), _executor, "incorrect-target");
    }

    function _verifyArbitrumReceiverDeployment(
        address _executor,
        address _receiver
    ) internal view {
        ArbitrumReceiver receiver = ArbitrumReceiver(_receiver);

        // L1 authority has to be the Ethereum Mainnet Grove Proxy
        assertEq(receiver.l1Authority(), Ethereum.GROVE_PROXY, "incorrect-l1-authority");

        // Target has to be the executor
        assertEq(receiver.target(), _executor, "incorrect-target");
    }

    function _verifyOptimismReceiverDeployment(
        address _executor,
        address _receiver
    ) internal view {
        OptimismReceiver receiver = OptimismReceiver(_receiver);

        // L1 authority has to be the Ethereum Mainnet Grove Proxy
        assertEq(receiver.l1Authority(), Ethereum.GROVE_PROXY, "incorrect-l1-authority");

        // Target has to be the executor
        assertEq(receiver.target(), _executor, "incorrect-target");
    }

    function _verifyLayerZeroReceiverDeployment(
        address _executor,
        address _receiver
    ) internal view {
        LZReceiver receiver = LZReceiver(_receiver);

        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);

        // Receiver's destination endpoint address has to be the correct one for the current chain
        // Currently supported chains - add more if needed
        if (currentChain == ChainIdUtils.Avalanche())
            assertEq(address(receiver.endpoint()), LZForwarder.ENDPOINT_AVALANCHE, "incorrect-destination-endpoint-address");

        else if (currentChain == ChainIdUtils.Base())
            assertEq(address(receiver.endpoint()), LZForwarder.ENDPOINT_BASE, "incorrect-destination-endpoint-address");

        else revert("incorrect-chain-id");

        // Receiver's destination endpoint id has to be the Ethereum Mainnet endpoint id
        assertEq(receiver.srcEid(), LZForwarder.ENDPOINT_ID_ETHEREUM, "incorrect-destination-endpoint-id");

        // Source authority has to be the Ethereum Mainnet Grove Proxy
        assertEq(receiver.sourceAuthority(), CastingHelpers.addressToLayerZeroRecipient(Ethereum.GROVE_PROXY), "incorrect-source-authority");

        // Target has to be the executor
        assertEq(receiver.target(), _executor, "incorrect-target");

        // Delegate has to be set to blank, non-zero address placeholder
        assertEq(
            ILayerZeroEndpointV2(address(receiver.endpoint())).delegates(address(receiver)),
            address(1),
            "incorrect-delegate"
        );

        // Owner has to be set to blank, non-zero address placeholder
        assertEq(receiver.owner(), address(1), "incorrect-owner");
    }

    function _testControllerUpgrade(address oldController, address newController) internal {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);

        GroveLiquidityLayerContext memory ctx = _getGroveLiquidityLayerContext();

        // Note the functions used are interchangable with mainnet and foreign controllers
        MainnetController controller = MainnetController(newController);

        bytes32 CONTROLLER = ctx.proxy.CONTROLLER();
        bytes32 RELAYER    = controller.RELAYER();
        bytes32 FREEZER    = controller.FREEZER();

        if (oldController != address(0)) {
            assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), true);
        }
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), false);


        if (oldController != address(0)) {
            assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), true);
        }
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), false);

        assertEq(controller.hasRole(RELAYER, ctx.relayer), false);
        assertEq(controller.hasRole(FREEZER, ctx.freezer), false);

        // Verify CCTPv1 recipients are not set

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(
                controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE),
                CastingHelpers.addressToCctpRecipient(address(0))
            );
            assertEq(
                controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
                CastingHelpers.addressToCctpRecipient(address(0))
            );
            // Intentionally skipping the following (CCTPv1 is not deployed there)
            // Plume
            // ...
        } else {
            assertEq(controller.mintRecipients(
                CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
                CastingHelpers.addressToCctpRecipient(address(0))
            );
        }

        // Verify Centrifuge recipients are not set

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(address(0))
            );
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.BASE_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(address(0))
            );
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(address(0))
            );
            // Intentionally skipping the following (Centrifuge is not deployed there)
            // ...
        } else {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(address(0))
            );
        }

        // Verify LayerZero recipients are not set

        // TODO: Implement checks that LayerZero recipients are not set

        executeAllPayloadsAndBridges();

        assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), false);
        assertEq(ctx.proxy.hasRole(CONTROLLER, newController), true);

        assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), false);
        assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), true);

        assertEq(controller.hasRole(RELAYER, ctx.relayer), true);
        assertEq(controller.hasRole(FREEZER, ctx.freezer), true);

        // Verify CCTPv1 recipients are set

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(
                controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE),
                CastingHelpers.addressToCctpRecipient(Avalanche.ALM_PROXY)
            );
            assertEq(
                controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
                CastingHelpers.addressToCctpRecipient(Base.ALM_PROXY)
            );
            // Intentionally skipping the following (CCTPv1 is not deployed there)
            // Plume
            // ...
        } else {
            assertEq(
                controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
                CastingHelpers.addressToCctpRecipient(Ethereum.ALM_PROXY)
            );
        }

        // Verify Centrifuge recipients are set

        if (currentChain == ChainIdUtils.Ethereum()) {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Avalanche.ALM_PROXY)
            );
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.BASE_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Base.ALM_PROXY)
            );
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.PLUME_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Plume.ALM_PROXY)
            );
            // Intentionally skipping the following (Centrifuge is not deployed there)
            // ...
        } else {
            assertEq(
                controller.centrifugeRecipients(GroveLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID),
                CastingHelpers.addressToCentrifugeRecipient(Ethereum.ALM_PROXY)
            );
        }

        // Verify LayerZero recipients are set

        // TODO: Implement checks that LayerZero recipients are set
    }

}
