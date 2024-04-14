// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract InsuranceCoverageNFT is AccessControlEnumerable, ERC721Enumerable {
    bytes32 public constant MANAGER_CONTRACT = keccak256("MANAGER_CONTRACT");

    constructor(address managerContract_) ERC721("InsuranceCoverage", "ICNFT") {
        _grantRole(MANAGER_CONTRACT, managerContract_);
    }

    // functions:
    // supportsInterface to override parents
    // mint - to mint NFT, manager contract only
    // burn - to burn NFT, owner only
    //

    // function mint(address to, uint256 tokenId) external {
    //     require(
    //         hasRole(MANAGER_CONTRACT, msg.sender),
    //         "InsuranceCoverageNFT: must have manager role to mint"
    //     );
    //     _safeMint(to, tokenId);
    // }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Enumerable, AccessControlEnumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
