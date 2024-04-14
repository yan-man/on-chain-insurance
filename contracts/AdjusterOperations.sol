// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract AdjusterOperations is AccessControlEnumerable {
    struct Adjuster {
        address adjuster;
        bool status;
    }

    uint256 public constant REQUIRED_APPROVERS = 1;
    uint256 public constant REQUIRED_ADJUSTERS = 3;
    bytes32 public constant MASTER_ADMIN = keccak256("MASTER_ADMIN"); // ability to add/remove insurance APPROVER_ADMIN
    bytes32 public constant APPROVER_ADMIN = keccak256("APPROVER_ADMIN"); // ability to add/remove insurance ADJUSTER

    mapping(address => Adjuster) public adjusters; // mapping of insurance adjusters
    uint256 public adjusterCount;

    event AdjusterOperations_AdjustersUpdated(
        address indexed adjuster,
        bool indexed status
    );

    error AdjusterOperations_InvalidZeroAddress();
    error AdjusterOperations_InvalidApprover();
    error AdjusterOperations_InvalidAdjuster();

    constructor(address masterAdmin_) {
        _grantRole(MASTER_ADMIN, masterAdmin_);
    }

    function addApprover(address approver_) external onlyRole(MASTER_ADMIN) {
        if (approver_ == address(0)) {
            revert AdjusterOperations_InvalidZeroAddress();
        }
        /// @dev Master admin shouldn't approve themselves as approver. Too much control
        if (hasRole(MASTER_ADMIN, approver_)) {
            revert AdjusterOperations_InvalidApprover();
        }
        _grantRole(APPROVER_ADMIN, approver_);
    }

    function removeApprover(address approver_) external onlyRole(MASTER_ADMIN) {
        _revokeRole(APPROVER_ADMIN, approver_);
    }

    function setInsuranceAdjuster(
        address adjuster_,
        bool status_
    ) external onlyRole(APPROVER_ADMIN) {
        if (adjuster_ == address(0)) {
            revert AdjusterOperations_InvalidZeroAddress();
        }
        /// @dev Approver shouldn't approve themselves as adjuster; adjuster also shouldn't be MASTER_ADMIN
        if (adjuster_ == msg.sender || hasRole(MASTER_ADMIN, adjuster_)) {
            revert AdjusterOperations_InvalidAdjuster();
        }

        Adjuster memory _currentAdjuster = adjusters[adjuster_];
        adjusters[adjuster_] = Adjuster({adjuster: adjuster_, status: status_});

        // adjust adjuster count only if status is changed, not id
        if (!_currentAdjuster.status && status_) {
            // from false -> true
            adjusterCount++;
        } else if (_currentAdjuster.status && !status_) {
            // from true -> false
            adjusterCount--;
        }
        emit AdjusterOperations_AdjustersUpdated(adjuster_, status_);
    }

    function isAdjuster(address adjuster_) external view returns (bool) {
        return adjusters[adjuster_].status;
    }

    function isInitialized() external view returns (bool) {
        return
            getRoleMemberCount(APPROVER_ADMIN) >= REQUIRED_APPROVERS &&
            adjusterCount >= REQUIRED_ADJUSTERS;
    }
}
