// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract InsuranceCoverageNFT is AccessControlEnumerable, ERC721Enumerable {
    struct PolicyDetails {
        uint256 id;
        uint256 premium; // in paymentToken, in $0.01/sec (ie 10 ** (decimals - 2))
        uint256 startTime; // timestamp
        uint256 endTime; // timestamp
        bool isActive;
    }

    bytes32 public constant MANAGER_CONTRACT = keccak256("MANAGER_CONTRACT");
    uint256 public constant MAX_COVERAGE_DURATION = 365 days;

    mapping(uint256 => PolicyDetails) public policyDetails; // tokenId => policy details
    uint256 public tokenId;

    event PolicyCreated(
        uint256 indexed tokenId,
        address indexed to,
        uint256 premium,
        uint256 startTime,
        uint256 endTime,
        bool isActive
    );
    event PolicyInactive(uint256 indexed tokenId);
    event PolicyExtended(
        uint256 indexed tokenId,
        uint256 indexed premium,
        uint256 startTime,
        uint256 endTime,
        bool isActive
    );

    error InsuranceCoverageNFT_NotOwner();
    error InsuranceCoverageNFT_InvalidPremium();
    error InsuranceCoverageNFT_InvalidCoverageDuration(
        uint256 coverageDuration
    );
    error InsuranceCoverageNFT_InactivePolicy();

    modifier onlyTokenOwner(uint256 tokenId_) {
        if (msg.sender != ownerOf(tokenId_)) {
            revert InsuranceCoverageNFT_NotOwner();
        }
        _;
    }

    constructor(address managerContract_) ERC721("InsuranceCoverage", "ICNFT") {
        _grantRole(MANAGER_CONTRACT, managerContract_);
    }

    function mint(
        address to_,
        uint256 premium_,
        uint256 coverageDuration_
    ) external onlyRole(MANAGER_CONTRACT) returns (uint256) {
        tokenId++;
        if (premium_ == 0) {
            revert InsuranceCoverageNFT_InvalidPremium();
        }
        if (
            coverageDuration_ == 0 || coverageDuration_ > MAX_COVERAGE_DURATION
        ) {
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
            startTime: _startTime,
            endTime: _endTime,
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
        return _tokenId;
    }

    function burn(uint256 tokenId_) external onlyTokenOwner(tokenId_) {
        _burn(tokenId_);

        policyDetails[tokenId_].endTime = block.timestamp;
        policyDetails[tokenId_].isActive = false;

        emit PolicyInactive(tokenId_);
    }

    function extendCoverage(
        uint256 tokenId_,
        uint256 coverageDuration_
    ) external onlyRole(MANAGER_CONTRACT) {
        PolicyDetails memory _policy = policyDetails[tokenId_];

        // check if policy is active and not expired
        if (!_policy.isActive || _policy.endTime < block.timestamp) {
            revert InsuranceCoverageNFT_InactivePolicy();
        }

        uint256 _remainingDuration = _policy.endTime - block.timestamp;
        // ensure the total duration never exceeds the MAX_COVERAGE_DURATION
        if (
            coverageDuration_ == 0 ||
            coverageDuration_ + _remainingDuration > MAX_COVERAGE_DURATION
        ) {
            revert InsuranceCoverageNFT_InvalidCoverageDuration(
                coverageDuration_
            );
        }
        _policy.endTime += coverageDuration_;
        policyDetails[tokenId_] = _policy;

        emit PolicyExtended(
            _policy.id,
            _policy.premium,
            _policy.startTime,
            _policy.endTime,
            _policy.isActive
        );
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
