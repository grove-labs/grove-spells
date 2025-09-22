// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";

import { IExecutor } from "lib/grove-gov-relay/src/interfaces/IExecutor.sol";

import { CCTPForwarder }          from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { ArbitrumERC20Forwarder } from "xchain-helpers/forwarders/ArbitrumERC20Forwarder.sol";

import { GroveLiquidityLayerHelpers } from "./GroveLiquidityLayerHelpers.sol";

/**
 * @dev Base smart contract for Ethereum.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadEthereum {

    // ADD SUPPORTED FOREIGN PAYLOADS HERE

    // These need to be immutable (delegatecall) and can only be set in constructor
    address public immutable PAYLOAD_AVALANCHE;
    address public immutable PAYLOAD_PLUME;

    function execute() external {
        _execute();

        if (PAYLOAD_AVALANCHE != address(0)) {
            CCTPForwarder.sendMessage({
                messageTransmitter:  CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM,
                destinationDomainId: CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
                recipient:           Avalanche.GROVE_RECEIVER,
                messageBody:         _encodePayloadQueue(PAYLOAD_AVALANCHE)
            });
        }

        if (PAYLOAD_PLUME != address(0)) {
            ArbitrumERC20Forwarder.sendMessageL1toL2({
                l1CrossDomain: ArbitrumERC20Forwarder.L1_CROSS_DOMAIN_PLUME,
                target:        Plume.GROVE_RECEIVER,
                message:       _encodePayloadQueue(PAYLOAD_PLUME),
                gasLimit:      500_0000,
                maxFeePerGas:  5e9,
                baseFee:       block.basefee
            });
        }
    }

    function _execute() internal virtual;

    function _encodePayloadQueue(address _payload) internal pure returns (bytes memory) {
        address[] memory targets        = new address[](1);
        uint256[] memory values         = new uint256[](1);
        string[] memory signatures      = new string[](1);
        bytes[] memory calldatas        = new bytes[](1);
        bool[] memory withDelegatecalls = new bool[](1);

        targets[0]           = _payload;
        values[0]            = 0;
        signatures[0]        = 'execute()';
        calldatas[0]         = '';
        withDelegatecalls[0] = true;

        return abi.encodeCall(IExecutor.queue, (
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls
        ));
    }

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        GroveLiquidityLayerHelpers.onboardERC4626Vault(
            Ethereum.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

    function _onboardERC7540Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        GroveLiquidityLayerHelpers.onboardERC7540Vault(
            Ethereum.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

    function _offboardERC7540Vault(address vault) internal {
        GroveLiquidityLayerHelpers.offboardERC7540Vault(
            Ethereum.ALM_RATE_LIMITS,
            vault
        );
    }

    function _setUSDSMintRateLimit(uint256 maxAmount, uint256 slope) internal {
        GroveLiquidityLayerHelpers.setUSDSMintRateLimit(
            Ethereum.ALM_RATE_LIMITS,
            maxAmount,
            slope
        );
    }

    function _setUSDSToUSDCRateLimit(uint256 maxAmount, uint256 slope) internal {
        GroveLiquidityLayerHelpers.setUSDSToUSDCRateLimit(
            Ethereum.ALM_RATE_LIMITS,
            maxAmount,
            slope
        );
    }

    function _setCentrifugeCrosschainTransferRateLimit(address centrifugeVault, uint16 destinationCentrifugeId, uint256 maxAmount, uint256 slope) internal {
        GroveLiquidityLayerHelpers.setCentrifugeCrosschainTransferRateLimit(
            Ethereum.ALM_RATE_LIMITS,
            centrifugeVault,
            destinationCentrifugeId,
            maxAmount,
            slope
        );
    }

}
