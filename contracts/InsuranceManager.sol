// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {RiskManager} from "./libraries/RiskManager.sol";
import {InsuranceCoverageNFT} from "./InsuranceCoverageNFT.sol";
import {AdjusterOperations} from "./AdjusterOperations.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InsuranceManager {
    using RiskManager for *;

    enum ApplicationStatus {
        Pending,
        Approved,
        Rejected,
        Claimed
    }
    struct Application {
        address applicant;
        uint256 tokenId;
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
    InsuranceCoverageNFT public insuranceCoverageNFT;
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
    event PolicyActivated(uint256 indexed applicationId);

    error InsuranceManager_InvalidValue(uint256 value);
    error InsuranceManager_InvalidCarDetails(bytes32 carDetails);
    error InsuranceManager_InvalidAdjuster(address adjuster);
    error InsuranceManager_InvalidApplicationStatus();
    error InsuranceManager_NotInitialized();
    error InsuranceManager_InvalidApplication(address applicant);
    error InsuranceManager_InvalidClaimant(address claimant);

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
        insuranceCoverageNFT = new InsuranceCoverageNFT(address(this));
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
            tokenId: 0,
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
            status_ == ApplicationStatus.Pending ||
            status_ == ApplicationStatus.Claimed
        ) {
            revert InsuranceManager_InvalidApplicationStatus();
        }
        if (status_ == ApplicationStatus.Approved) {
            _application.premium =
                RiskManager.calculatePremium(_application.value, riskFactor_) *
                (10 ** ERC20(address(paymentToken)).decimals());
            _application.riskFactor = riskFactor_;
        } else if (status_ == ApplicationStatus.Rejected) {
            _uniqueApplicationHashes[_application.carDetails] = false; // reset the hash as it is no longer in use
        }

        _application.status = status_;
        _application.reviewTimestamp = block.timestamp;
        applications[applicationId_] = _application;

        emit ApplicationReviewed(applicationId_, status_);
    }

    function activatePolicy(uint256 applicationId_, uint256 amount_) external {
        Application memory _application = applications[applicationId_];
        if (_application.status != ApplicationStatus.Approved) {
            revert InsuranceManager_InvalidApplicationStatus();
        }
        if (block.timestamp > _application.reviewTimestamp + MAX_TIME_WINDOW) {
            revert InsuranceManager_InvalidApplicationStatus();
        }

        paymentToken.transferFrom(
            _application.applicant,
            address(this),
            amount_
        );
        uint256 _tokenId = insuranceCoverageNFT.mint(
            _application.applicant,
            _application.premium,
            RiskManager.calculateDuration(amount_, _application.premium)
        );
        _application.isPaid = true;
        _application.tokenId = _tokenId;
        applications[applicationId_] = _application;

        emit PolicyActivated(applicationId_);
    }

    function extendCoverage(uint256 applicationId_, uint256 amount_) external {
        Application memory _application = applications[applicationId_];
        insuranceCoverageNFT.extendCoverage(
            _application.tokenId,
            amount_.calculateDuration(_application.premium)
        );
    }

    function claimPolicy(uint256 applicationId_) external {
        Application memory _application = applications[applicationId_];
        if (insuranceCoverageNFT.ownerOf(_application.tokenId) != msg.sender) {
            revert InsuranceManager_InvalidClaimant(msg.sender);
        }
        if (_application.status != ApplicationStatus.Approved) {
            revert InsuranceManager_InvalidApplicationStatus();
        }
        _application.status = ApplicationStatus.Claimed;
        applications[applicationId_] = _application;

        emit PolicyActivated(applicationId_);
    }
}
