// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import {InsuranceCoverageNFT} from "./InsuranceCoverageNFT.sol";
import {AdjusterOperations} from "./AdjusterOperations.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InsuranceManager is AccessControlEnumerable {
    enum ApplicationStatus {
        Pending,
        Approved,
        Rejected
    }
    struct Application {
        address applicant;
        uint256 value; // in paymentToken including decimals
        uint256 riskFactor; // 1-100
        uint256 submissionTimestamp;
        uint256 premium; // in paymentToken, in $0.01/sec (ie 10 ** (decimals - 2))
        bytes32 carDetails; // keccak256-hashed
        bool isPaid;
        ApplicationStatus status;
    }

    uint256 public constant MAX_VALUE = 1e6; // without decimals, ie $1M
    uint256 public constant MAX_RISK_FACTOR = 100;
    uint256 public constant MAX_TIME_WINDOW = 7 days; // window for premium payment

    mapping(uint256 => Application) public applications; // applicationId => Application
    InsuranceCoverageNFT public insuranceNFT;
    AdjusterOperations public adjusterOperations;
    IERC20 public paymentToken;
    uint256 public nextApplicationId;
    mapping(bytes32 => bool) private _uniqueApplicationHashes; // keccak256-hashed carDetails => in progress

    event ApplicationSubmitted(
        uint256 indexed applicationId,
        address indexed applicant,
        uint256 value
    );

    error InsuranceManager_InvalidValue(uint256 value);
    error InsuranceManager_InvalidCarDetails(bytes32 carDetails);

    constructor(address adjusterOpsAddress_, address paymentTokenAddress_) {
        insuranceNFT = new InsuranceCoverageNFT(address(this));
        adjusterOperations = AdjusterOperations(adjusterOpsAddress_);
        paymentToken = IERC20(paymentTokenAddress_);
    }

    function submitApplication(uint256 value_, bytes32 carDetails_) public {
        if (value_ == 0 || value_ > MAX_VALUE) {
            revert InsuranceManager_InvalidValue(value_);
        }
        if (_uniqueApplicationHashes[carDetails_]) {
            revert InsuranceManager_InvalidCarDetails(carDetails_);
        }
        uint256 _applicationId = nextApplicationId;
        _uniqueApplicationHashes[carDetails_] = true;
        applications[_applicationId] = Application({
            applicant: msg.sender,
            value: value_ * (10 ** ERC20(address(paymentToken)).decimals()),
            riskFactor: 0, // Initial risk factor set to 0
            premium: 0, // Initial premium set to 0
            submissionTimestamp: block.timestamp,
            status: ApplicationStatus.Pending,
            isPaid: false,
            carDetails: carDetails_
        });
        emit ApplicationSubmitted(_applicationId, msg.sender, value_);
        nextApplicationId++;
    }

    // methods:
    // applyForInsurance
    // approveInsurance
    // claimInsurance
}
