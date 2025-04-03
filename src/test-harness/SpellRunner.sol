// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import { Ethereum } from "bloom-address-registry/Ethereum.sol";

abstract contract SpellRunner is Test {

    struct SpellMetadata {
      address payload;
      address executor;
    }

    SpellMetadata internal spellMetadata;

    string internal id;

    /// @dev to be called in setUp
    function setupDomain(uint256 mainnetForkBlock) internal {
        vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetForkBlock);
        spellMetadata.executor = Ethereum.BLOOM_PROXY;
    }

    function spellIdentifier() private view returns(string memory){
        string memory slug       = string(abi.encodePacked("BloomEthereum_", id));
        string memory identifier = string(abi.encodePacked(slug, ".sol:", slug));
        return identifier;
    }

    function deployPayload() internal returns(address) {
        spellMetadata.payload = deployCode(spellIdentifier());
        return spellMetadata.payload;
    }

    function executePayload() internal {
        address payloadAddress = spellMetadata.payload;
        address executor       = spellMetadata.executor;

        require(_isContract(payloadAddress), "PAYLOAD IS NOT A CONTRACT");

        vm.prank(Ethereum.PAUSE_PROXY);
        (bool success,) = executor.call(abi.encodeWithSignature(
            "exec(address,bytes)",
            payloadAddress,
            abi.encodeWithSignature("execute()")
        ));
        require(success, "FAILED TO EXECUTE PAYLOAD");
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

}
