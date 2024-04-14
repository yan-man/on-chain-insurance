// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {InsuranceCoverageNFT} from "./InsuranceCoverageNFT.sol";
import {AdjusterOperations} from "./AdjusterOperations.sol";
import {YieldManager} from "./YieldManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title InsuranceManager
/// @author YBM
contract InsuranceManager {
    enum ApplicationStatus {
        Pending,
        Approved,
        Rejected,
        Claimed
    }
    struct Application {
        address applicant;
        uint256 tokenId;
        uint256 value; // in paymentToken with decimals
        uint256 riskFactor; // 1-100
        uint256 submissionTimestamp;
        uint256 reviewTimestamp;
        uint256 premium; // in paymentToken including decimals
        bytes32 carDetails; // keccak256-hashed
        bool isPaid;
        ApplicationStatus status;
    }

    uint256 public constant MIN_VALUE = 1e20; // assume 18 token decimals, ie $1K
    uint256 public constant MAX_VALUE = 1e24; // assume 18 token decimals, ie $1M
    uint256 public constant MAX_RISK_FACTOR = 100;
    uint256 public constant MAX_TIME_WINDOW = 7 days; // window for premium payment

    mapping(uint256 => Application) public applications; // applicationId => Application
    InsuranceCoverageNFT public insuranceCoverageNFT;
    AdjusterOperations public adjusterOperations;
    YieldManager public yieldManager;
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
    event PolicyClaimed(uint256 indexed applicationId);

    error InsuranceManager_InvalidValue(uint256 value);
    error InsuranceManager_InvalidCarDetails(bytes32 carDetails);
    error InsuranceManager_InvalidAdjuster(address adjuster);
    error InsuranceManager_InvalidApplicationStatus();
    error InsuranceManager_NotInitialized();
    error InsuranceManager_InvalidApplication(address applicant);
    error InsuranceManager_InvalidClaimant(address claimant);
    error InsuranceManager_InsufficientFunds();

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

    constructor(
        address adjusterOperationsAddress_,
        address paymentTokenAddress_,
        address poolAddress_
    ) {
        insuranceCoverageNFT = new InsuranceCoverageNFT(address(this));
        yieldManager = new YieldManager(
            address(this),
            poolAddress_,
            paymentTokenAddress_
        );
        adjusterOperations = AdjusterOperations(adjusterOperationsAddress_);
        paymentToken = IERC20(paymentTokenAddress_);
    }

    /// @dev submitApplication to apply for insurance
    /// @param value_ The insured value in paymentToken with decimals
    /// @param carDetails_ The keccak256-hashed car details
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

    /// @dev reviewApplication to approve or reject an application
    /// @param applicationId_ The application ID
    /// @param riskFactor_ The risk factor, ranging from 1 to 100
    /// @param status_ The application status
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
            _application.premium = calculatePremium(
                _application.value,
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

    /// @dev activatePolicy to activate an approved policy
    /// @param applicationId_ The application ID
    /// @param amount_ The amount to be paid in paymentToken
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
            address(yieldManager),
            amount_
        );
        uint256 _tokenId = insuranceCoverageNFT.mint(
            _application.applicant,
            _application.premium,
            _calculateDuration(amount_, _application.premium)
        );
        _application.isPaid = true;
        _application.tokenId = _tokenId;
        applications[applicationId_] = _application;

        emit PolicyActivated(applicationId_);
    }

    /// @dev extendCoverage to extend the coverage duration of an active policy
    /// @param applicationId_ The application ID
    /// @param amount_ The amount to be paid in paymentToken
    function extendCoverage(uint256 applicationId_, uint256 amount_) external {
        Application memory _application = applications[applicationId_];
        insuranceCoverageNFT.extendCoverage(
            _application.tokenId,
            _calculateDuration(amount_, _application.premium)
        );
    }

    /// @dev claimPolicy to claim the insurance policy
    /// @param applicationId_ The application ID
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

        if (yieldManager.getAvailableBalance() >= _application.value) {
            yieldManager.withdraw(_application.value, msg.sender);
        } else {
            revert InsuranceManager_InsufficientFunds();
        }

        emit PolicyClaimed(applicationId_);
    }

    /// @dev Calculates insurance premium based on the insured value and risk factor.
    /// @param value_ The insured value.
    /// @param riskFactor_ The risk factor, ranging from 1 to 100.
    /// @return premium The calculated premium in paymentToken, with decimals.
    function calculatePremium(
        uint256 value_,
        uint256 riskFactor_
    ) public pure returns (uint256) {
        // Base premium is 1% of the value
        uint256 basePercentageInBIPs = 100;
        // Additional premium is up to 2% of the value based on riskFactor_
        uint256 additionalPercentageInBIPs = (200 * riskFactor_) / 100; // Max 400 when riskFactor is 100

        uint256 totalPercentage = basePercentageInBIPs +
            additionalPercentageInBIPs;
        uint256 premium = (value_ * totalPercentage) / 10000; // Dividing by 10000 to account for percentage calculation

        return premium;
    }

    /// @dev Calculates the duration of the insurance policy based on the amount of token paid and premium cost
    /// @param amount_ The amount to be paid in paymentToken
    /// @param premium_ The premium to be paid in paymentToken
    /// @return duration The duration of the insurance policy in seconds
    function _calculateDuration(
        uint256 amount_,
        uint256 premium_
    ) internal pure returns (uint256) {
        return amount_ / premium_;
    }
}
