// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

library CastingHelpers {

    function addressToLeftPaddedBytes32(address value) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }

    function leftPaddedBytes32ToAddress(bytes32 value) internal pure returns (address) {
        return address(uint160(uint256(value)));
    }

    function addressToRightPaddedBytes32(address value) internal pure returns (bytes32) {
        return bytes32(bytes20(value));
    }

    function rightPaddedBytes32ToAddress(bytes32 value) internal pure returns (address) {
        return address(bytes20(value));
    }

    function addressToCctpRecipient(address value) internal pure returns (bytes32) {
        return addressToLeftPaddedBytes32(value);
    }

    function cctpRecipientToAddress(bytes32 value) internal pure returns (address) {
        return leftPaddedBytes32ToAddress(value);
    }

    function addressToLayerZeroRecipient(address value) internal pure returns (bytes32) {
        return addressToLeftPaddedBytes32(value);
    }

    function layerZeroRecipientToAddress(bytes32 value) internal pure returns (address) {
        return leftPaddedBytes32ToAddress(value);
    }

    function addressToCentrifugeRecipient(address value) internal pure returns (bytes32) {
        return addressToRightPaddedBytes32(value);
    }

    function centrifugeRecipientToAddress(bytes32 value) internal pure returns (address) {
        return rightPaddedBytes32ToAddress(value);
    }
}
