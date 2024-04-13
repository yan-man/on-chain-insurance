// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract InsuranceRegistry is AccessControlEnumerable {
    error InsuranceRegistry_OnlyMasterAdmin();

    bytes32 public constant MASTER_ADMIN = keccak256("MASTER_ADMIN"); // ability to add/remove insurance APPROVER_ADMIN
    bytes32 public constant APPROVER_ADMIN = keccak256("APPROVER_ADMIN"); // ability to add/remove insurance ADJUSTER

    constructor(address masterAdmin_) {
        _grantRole(MASTER_ADMIN, masterAdmin_);
    }
}
