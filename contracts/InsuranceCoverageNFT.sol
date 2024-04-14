// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract InsuranceCoverageNFT is AccessControlEnumerable, ERC721 {
    bytes32 public constant MANAGER_ADMIN = keccak256("MANAGER_ADMIN");

    constructor(address managerAdmin_) ERC721("InsuranceCoverage", "ICNFT") {
        _grantRole(MANAGER_ADMIN, managerAdmin_);
    }

    // functions:
    // supportsInterface to override parents
    // mint - to mint NFT, manager contract only
    // burn - to burn NFT, owner only
    //
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControlEnumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
