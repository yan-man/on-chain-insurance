// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import {InsuranceCoverageNFT} from "./InsuranceCoverageNFT.sol";
import {AdjusterOperations} from "./AdjusterOperations.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InsuranceManager is AccessControlEnumerable {
    enum ApplicationStatus {
        Pending,
        Approved,
        Rejected
    }
    struct Application {
        address applicant;
        uint256 value;
        uint256 riskFactor; // 0-100
        uint256 submissionTimestamp;
        uint256 premium;
        ApplicationStatus status;
    }

    InsuranceCoverageNFT public insuranceNFT;
    AdjusterOperations public adjusterOperations;
    IERC20 public paymentToken;

    constructor(address adjusterOpsAddress_, address paymentTokenAddress_) {
        insuranceNFT = new InsuranceCoverageNFT(address(this));
        adjusterOperations = AdjusterOperations(adjusterOpsAddress_);
        paymentToken = IERC20(paymentTokenAddress_);
    }

    // function applyForInsurance() public {

    // }

    // methods:
    // applyForInsurance
    // approveInsurance
    // claimInsurance
}
