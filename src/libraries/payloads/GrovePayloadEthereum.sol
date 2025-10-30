// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";
import { Plasma }    from "lib/grove-address-registry/src/Plasma.sol";

import { IExecutor } from "lib/grove-gov-relay/src/interfaces/IExecutor.sol";

import { ArbitrumERC20Forwarder }            from "xchain-helpers/forwarders/ArbitrumERC20Forwarder.sol";
import { CCTPForwarder }                     from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { LZForwarder, ILayerZeroEndpointV2 } from "xchain-helpers/forwarders/LZForwarder.sol";
import { OptimismForwarder }                 from "xchain-helpers/forwarders/OptimismForwarder.sol";

import { OptionsBuilder } from "lib/xchain-helpers/lib/devtools/packages/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import { CastingHelpers }             from "../helpers/CastingHelpers.sol";
import { GroveLiquidityLayerHelpers } from "../helpers/GroveLiquidityLayerHelpers.sol";


/**
 * @dev Base smart contract for Ethereum.
 * @author Steakhouse Financial
 */
abstract contract GrovePayloadEthereum {

    using OptionsBuilder for bytes;

    // These need to be immutable (delegatecall) and can only be set in constructor
    address public immutable PAYLOAD_AVALANCHE;
    address public immutable PAYLOAD_PLUME;
    address public immutable PAYLOAD_BASE;
    address public immutable PAYLOAD_PLASMA;

    function execute() external {
        _execute();

        if (PAYLOAD_AVALANCHE != address(0)) {
            CCTPForwarder.sendMessage({
                messageTransmitter  : CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM,
                destinationDomainId : CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
                recipient           : Avalanche.GROVE_RECEIVER,
                messageBody         : _encodePayloadQueue(PAYLOAD_AVALANCHE)
            });
        }

        if (PAYLOAD_PLUME != address(0)) {
            ArbitrumERC20Forwarder.sendMessageL1toL2({
                l1CrossDomain : ArbitrumERC20Forwarder.L1_CROSS_DOMAIN_PLUME,
                target        : Plume.GROVE_RECEIVER,
                message       : _encodePayloadQueue(PAYLOAD_PLUME),
                gasLimit      : 1_000_0000,
                maxFeePerGas  : 5_000e9,
                baseFee       : block.basefee
            });
        }

        if (PAYLOAD_BASE != address(0)) {
            OptimismForwarder.sendMessageL1toL2({
                l1CrossDomain : OptimismForwarder.L1_CROSS_DOMAIN_BASE,
                target        : Base.GROVE_RECEIVER,
                message       : _encodePayloadQueue(PAYLOAD_BASE),
                gasLimit      : 1_000_000
            });
        }

        if (PAYLOAD_PLASMA != address(0)) {
            bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(1_000_000, 0);

            LZForwarder.sendMessage({
                _dstEid        : LZForwarder.ENDPOINT_ID_PLASMA,
                _receiver      : CastingHelpers.addressToLayerZeroRecipient(Plasma.GROVE_RECEIVER),
                endpoint       : ILayerZeroEndpointV2(LZForwarder.ENDPOINT_ETHEREUM),
                _message       : _encodePayloadQueue(PAYLOAD_PLASMA),
                _options       : options,
                _refundAddress : Ethereum.GROVE_PROXY,
                _payInLzToken  : false
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

    function _onboardAaveToken(address token, uint256 depositMax, uint256 depositSlope) internal {
        GroveLiquidityLayerHelpers.onboardAaveToken(
            Ethereum.ALM_RATE_LIMITS,
            token,
            depositMax,
            depositSlope
        );
    }

    function _onboardCurvePool(
        address controller,
        address pool,
        uint256 maxSlippage,
        uint256 swapMax,
        uint256 swapSlope,
        uint256 depositMax,
        uint256 depositSlope,
        uint256 withdrawMax,
        uint256 withdrawSlope
    ) internal {
        GroveLiquidityLayerHelpers.onboardCurvePool(
            controller,
            Ethereum.ALM_RATE_LIMITS,
            pool,
            maxSlippage,
            swapMax,
            swapSlope,
            depositMax,
            depositSlope,
            withdrawMax,
            withdrawSlope
        );
    }

}
