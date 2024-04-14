// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract InsuranceCoverageNFT is AccessControlEnumerable, ERC721Enumerable {
    struct PolicyDetails {
        uint256 id;
        uint256 premium; // in token decimals/sec
        uint256 startDate; // timestamp
        uint256 endDate; // timestamp
        bool isActive;
    }

    mapping(uint256 => PolicyDetails) public policyDetails; // tokenId => policy details
    bytes32 public constant MANAGER_CONTRACT = keccak256("MANAGER_CONTRACT");
    uint256 public tokenId;

    event PolicyCreated(
        uint256 indexed tokenId,
        address indexed to,
        uint256 indexed premium,
        uint256 startDate,
        uint256 endDate,
        bool isActive
    );

    error InsuranceCoverageNFT_NotOwner();
    error InsuranceCoverageNFT_InvalidPremium();
    error InsuranceCoverageNFT_InvalidCoverageDuration(
        uint256 coverageDuration
    );
    error InsuranceCoverageNFT_InactivePolicy();

    constructor(address managerContract_) ERC721("InsuranceCoverage", "ICNFT") {
        _grantRole(MANAGER_CONTRACT, managerContract_);
    }

    // functions:
    // supportsInterface to override parents
    // mint - to mint NFT, manager contract only
    // burn - to burn NFT, owner only
    //

    modifier onlyTokenOwner(uint256 tokenId_) {
        if (msg.sender != ownerOf(tokenId_)) {
            revert InsuranceCoverageNFT_NotOwner();
        }
        _;
    }

    function mint(
        address to_,
        uint256 premium_,
        uint256 coverageDuration_
    ) external onlyRole(MANAGER_CONTRACT) {
        if (premium_ == 0) {
            revert InsuranceCoverageNFT_InvalidPremium();
        }
        if (coverageDuration_ == 0 || coverageDuration_ > 365 days) {
            revert InsuranceCoverageNFT_InvalidCoverageDuration(
                coverageDuration_
            );
        }

        uint256 _tokenId = tokenId;
        _safeMint(to_, _tokenId);

        uint256 _startTime = block.timestamp;
        uint256 _endTime = _startTime + coverageDuration_;
        bool _isActive = true;
        policyDetails[_tokenId] = PolicyDetails({
            id: _tokenId,
            premium: premium_,
            startDate: _startTime,
            endDate: _endTime,
            isActive: _isActive
        });

        emit PolicyCreated(
            _tokenId,
            to_,
            premium_,
            _startTime,
            _endTime,
            _isActive
        );
        tokenId++;
    }

    // function extendCoverage(
    //     uint256 tokenId_,
    //     uint256 coverageDuration_
    // ) external onlyTokenOwner(tokenId_) {
    //     PolicyDetails memory _policy = policyDetails[tokenId_];
    //     if (!_policy.isActive || _policy.endDate < block.timestamp) {
    //         revert InsuranceCoverageNFT_InactivePolicy();
    //     }

    //     if (
    //         coverageDuration_ == 0 ||
    //         coverageDuration_ > (_policy.endDate - block.timestamp)
    //     ) {
    //         revert InsuranceCoverageNFT_InvalidCoverageDuration(
    //             coverageDuration_
    //         );
    //     }
    // }

    function burn(uint256 tokenId_) public onlyTokenOwner(tokenId_) {
        _burn(tokenId);
        policyDetails[tokenId].isActive = false;
    }

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
