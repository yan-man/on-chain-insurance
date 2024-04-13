// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract InsuranceRegistry is AccessControlEnumerable {
    error InsuranceRegistry_OnlyMasterAdmin();
    error InsuranceRegistry_InvalidApprover();

    bytes32 public constant MASTER_ADMIN = keccak256("MASTER_ADMIN"); // ability to add/remove insurance APPROVER_ADMIN
    bytes32 public constant APPROVER_ADMIN = keccak256("APPROVER_ADMIN"); // ability to add/remove insurance ADJUSTER

    modifier onlyMasterAdmin() {
        if (!hasRole(MASTER_ADMIN, msg.sender)) {
            revert InsuranceRegistry_OnlyMasterAdmin();
        }
        _;
    }

    constructor(address masterAdmin_) {
        _grantRole(MASTER_ADMIN, masterAdmin_);
    }

    function addInsuranceApprover(address approver_) external onlyMasterAdmin {
        /// @dev Master admin shouldn't approve themselves as approver. Too much control
        if (hasRole(MASTER_ADMIN, approver_)) {
            revert InsuranceRegistry_InvalidApprover();
        }
        _grantRole(APPROVER_ADMIN, approver_);
    }
}
