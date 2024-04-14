// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import {RiskManager} from "./libraries/RiskManager.sol";
import {InsuranceCoverageNFT} from "./InsuranceCoverageNFT.sol";
import {AdjusterOperations} from "./AdjusterOperations.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InsuranceManager is AccessControlEnumerable {
    using RiskManager for uint256;

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
        uint256 reviewTimestamp;
        uint256 premium; // in paymentToken including decimals
        bytes32 carDetails; // keccak256-hashed
        bool isPaid;
        ApplicationStatus status;
    }

    uint256 public constant MIN_VALUE = 1e2; // without token decimals, ie $1K
    uint256 public constant MAX_VALUE = 1e6; // without token decimals, ie $1M
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
    event ApplicationReviewed(
        uint256 indexed applicationId,
        ApplicationStatus status
    );

    error InsuranceManager_InvalidValue(uint256 value);
    error InsuranceManager_InvalidCarDetails(bytes32 carDetails);
    error InsuranceManager_InvalidAdjuster(address adjuster);
    error InsuranceManager_InvalidApplicationStatus();
    error InsuranceManager_NotInitialized();
    error InsuranceManager_InvalidApplication(address applicant);

    modifier requireAdjusterOperationsInitialized() {
        if (!adjusterOperations.isInitialized()) {
            revert InsuranceManager_NotInitialized();
        }
        _;
    }

    modifier requireNonAdmin() {
        if (
            adjusterOperations.isAdjuster(msg.sender) ||
            adjusterOperations.hasRole(
                adjusterOperations.APPROVER_ADMIN(),
                msg.sender
            )
        ) {
            revert InsuranceManager_InvalidApplication(msg.sender);
        }
        _;
    }

    constructor(address adjusterOpsAddress_, address paymentTokenAddress_) {
        insuranceNFT = new InsuranceCoverageNFT(address(this));
        adjusterOperations = AdjusterOperations(adjusterOpsAddress_);
        paymentToken = IERC20(paymentTokenAddress_);
    }

    function submitApplication(
        uint256 value_,
        bytes32 carDetails_
    )
        external
        requireAdjusterOperationsInitialized
        requireNonAdmin
        returns (uint256)
    {
        if (value_ < MIN_VALUE || value_ > MAX_VALUE) {
            revert InsuranceManager_InvalidValue(value_);
        }
        if (_uniqueApplicationHashes[carDetails_]) {
            revert InsuranceManager_InvalidCarDetails(carDetails_);
        }
        uint256 _applicationId = nextApplicationId;
        _uniqueApplicationHashes[carDetails_] = true;
        applications[_applicationId] = Application({
            applicant: msg.sender,
            value: value_,
            riskFactor: 0, // Initial risk factor set to 0
            premium: 0, // Initial premium set to 0
            submissionTimestamp: block.timestamp,
            reviewTimestamp: 0,
            status: ApplicationStatus.Pending,
            isPaid: false,
            carDetails: carDetails_
        });
        emit ApplicationSubmitted(_applicationId, msg.sender, value_);
        nextApplicationId++;
        return _applicationId;
    }

    function reviewApplication(
        uint256 applicationId_,
        uint256 riskFactor_,
        ApplicationStatus status_
    ) external {
        if (!adjusterOperations.isAdjuster(msg.sender)) {
            revert InsuranceManager_InvalidAdjuster(msg.sender);
        }
        Application memory _application = applications[applicationId_];
        if (
            _application.status != ApplicationStatus.Pending ||
            status_ == ApplicationStatus.Pending
        ) {
            revert InsuranceManager_InvalidApplicationStatus();
        }
        if (status_ == ApplicationStatus.Approved) {
            _application.premium = _application.value.calculatePremium(
                riskFactor_
            );
            _application.riskFactor = riskFactor_;
        } else if (status_ == ApplicationStatus.Rejected) {
            _uniqueApplicationHashes[_application.carDetails] = false; // reset the hash as it is no longer in use
        }

        _application.status = status_;
        _application.reviewTimestamp = block.timestamp;
        applications[applicationId_] = _application;

        emit ApplicationReviewed(applicationId_, status_);
    }

    // function activatePolicy(uint256 applicationId_, uint256 amount_) external {
    //     Application memory _application = applications[applicationId_];
    //     if (_application.status != ApplicationStatus.Approved) {
    //         revert InsuranceManager_InvalidApplicationStatus();
    //     }
    //     if (
    //         block.timestamp > _application.submissionTimestamp + MAX_TIME_WINDOW
    //     ) {
    //         revert InsuranceManager_InvalidApplicationStatus();
    //     }

    //     paymentToken.transferFrom(
    //         _application.applicant,
    //         address(this),
    //         _application.premium
    //     );
    //     insuranceNFT.mint(
    //         _application.applicant,
    //         _application.premium,
    //         MAX_TIME_WINDOW
    //     );
    //     _application.isPaid = true;
    //     applications[applicationId_] = _application;
    // }

    // methods:
    // applyForInsurance
    // approveInsurance
    // claimInsurance
}
