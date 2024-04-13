// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract InsuranceRegistry is AccessControlEnumerable {
    event InsuranceRegistry_AdjustersUpdated(
        address indexed adjuster,
        bool indexed status
    );

    error InsuranceRegistry_InvalidZeroAddress();
    error InsuranceRegistry_InvalidApprover();
    error InsuranceRegistry_InvalidAdjuster();

    bytes32 public constant MASTER_ADMIN = keccak256("MASTER_ADMIN"); // ability to add/remove insurance APPROVER_ADMIN
    bytes32 public constant APPROVER_ADMIN = keccak256("APPROVER_ADMIN"); // ability to add/remove insurance ADJUSTER

    // bool public isInitialized; // flag to check if the contract is initialized; should have at least 3 insurance adjusters
    mapping(address => bool) public adjusters; // mapping of insurance adjusters

    constructor(address masterAdmin_) {
        _grantRole(MASTER_ADMIN, masterAdmin_);
    }

    function addApprover(address approver_) external onlyRole(MASTER_ADMIN) {
        if (approver_ == address(0)) {
            revert InsuranceRegistry_InvalidZeroAddress();
        }
        /// @dev Master admin shouldn't approve themselves as approver. Too much control
        if (hasRole(MASTER_ADMIN, approver_)) {
            revert InsuranceRegistry_InvalidApprover();
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
            revert InsuranceRegistry_InvalidZeroAddress();
        }
        /// @dev Approver shouldn't approve themselves as adjuster; adjuster also shouldn't be MASTER_ADMIN
        if (adjuster_ == msg.sender || hasRole(MASTER_ADMIN, adjuster_)) {
            revert InsuranceRegistry_InvalidAdjuster();
        }

        adjusters[adjuster_] = status_;
        emit InsuranceRegistry_AdjustersUpdated(adjuster_, status_);
    }

    // function isAdjuster(address adjuster_) public view returns (bool) {
    //     return adjusters[adjuster_];
    // }
}
