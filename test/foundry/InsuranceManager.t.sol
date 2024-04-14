// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
// import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {CustomTest} from "../helpers/CustomTest.t.sol";
import {Test, console} from "forge-std/Test.sol";

import {AdjusterOperations} from "../../contracts/AdjusterOperations.sol";
import {DeployAdjusterOperations} from "../../script/DeployAdjusterOperations.s.sol";
import {DeployInsuranceManager} from "../../script/DeployInsuranceManager.s.sol";
import {InsuranceCoverageNFT} from "../../contracts/InsuranceCoverageNFT.sol";
import {InsuranceManager} from "../../contracts/InsuranceManager.sol";
import {MockPool} from "../../contracts/mocks/MockPool.sol";
import {SampleERC20} from "../../contracts/mocks/SampleERC20.sol";
import {YieldManager} from "../../contracts/YieldManager.sol";

contract InsuranceManagerTest is Test, CustomTest {
    struct CarDetails {
        string name;
        string model;
        string year;
        string licensePlate;
    }

    DeployInsuranceManager.InsuranceManagerArgs public args;
    DeployInsuranceManager public deployInsuranceManager;
    InsuranceCoverageNFT public insuranceCoverageNFT;
    AdjusterOperations public adjusterOperations;
    InsuranceManager public insuranceManager;
    YieldManager public yieldManager;
    MockPool public mockPool;
    SampleERC20 public mockToken;
    SampleERC20 public mockAToken;

    address public masterAdmin;
    address[] public approverAdmins;
    address[] public adjusterAdmins;
    mapping(address => bool) public disallowedApplicants;

    function setUp() external {
        masterAdmin = vm.addr(getCounterAndIncrement());

        address[] memory tokens = new address[](1);
        address[] memory aTokens = new address[](1);

        mockToken = new SampleERC20();
        mockAToken = new SampleERC20();

        tokens[0] = address(mockToken);
        aTokens[0] = address(mockAToken);

        mockPool = new MockPool(tokens, aTokens);

        DeployAdjusterOperations deployAdjusterOperations = new DeployAdjusterOperations();
        deployAdjusterOperations.setConstructorArgs(
            DeployAdjusterOperations.AdjusterOperationsArgs({
                masterAdmin: masterAdmin
            })
        );
        adjusterOperations = deployAdjusterOperations.run();

        deployInsuranceManager = new DeployInsuranceManager();
        args = DeployInsuranceManager.InsuranceManagerArgs({
            adjusterOperationsAddress: address(adjusterOperations),
            paymentTokenAddress: address(mockToken),
            poolAddress: address(mockPool)
        });
        deployInsuranceManager.setConstructorArgs(args);

        insuranceManager = deployInsuranceManager.run();
        insuranceCoverageNFT = insuranceManager.insuranceCoverageNFT();
        yieldManager = insuranceManager.yieldManager();
        _setUpAdjusterOperations();
    }

    function _setUpAdjusterOperations() internal {
        uint256 _numApprovers = adjusterOperations.REQUIRED_APPROVERS();
        address _approverAdmin;
        vm.startPrank(masterAdmin);
        for (uint256 i = _numApprovers; i > 0; --i) {
            _approverAdmin = vm.addr(getCounterAndIncrement());
            adjusterOperations.addApprover(_approverAdmin);
            approverAdmins.push(_approverAdmin);
            disallowedApplicants[_approverAdmin] = true;
        }
        vm.stopPrank();
        vm.startPrank(_approverAdmin);
        uint256 numAdjusters = adjusterOperations.REQUIRED_ADJUSTERS();
        address _adjusterAdmin;
        for (uint256 i = numAdjusters; i > 0; --i) {
            _adjusterAdmin = vm.addr(getCounterAndIncrement());
            adjusterOperations.setInsuranceAdjuster(_adjusterAdmin, true);
            adjusterAdmins.push(_adjusterAdmin);
            disallowedApplicants[_adjusterAdmin] = true;
        }
        vm.stopPrank();
    }

    function _disableAdjuster(address adjuster_) internal {
        vm.startPrank(approverAdmins[0]);
        adjusterOperations.setInsuranceAdjuster(adjuster_, false);
        vm.stopPrank();
    }

    function _createPendingApplication(
        uint256 value_,
        bytes32 carDetails_,
        address applicant_
    ) internal returns (uint256) {
        vm.startPrank(applicant_);
        uint256 _applicationId = insuranceManager.submitApplication(
            value_,
            carDetails_
        );
        vm.stopPrank();
        return _applicationId;
    }

    function test_deploymentParams_success() external view {
        assertTrue(adjusterOperations.isInitialized());
        assertEq(
            address(insuranceManager.adjusterOperations()),
            address(adjusterOperations)
        );
        assertEq(address(insuranceManager.paymentToken()), address(mockToken));
        assertEq(
            insuranceManager.insuranceCoverageNFT().name(),
            "InsuranceCoverage"
        );
        assertEq(insuranceManager.insuranceCoverageNFT().symbol(), "ICNFT");
    }

    function test_submitApplication_success(
        uint256 value_,
        bytes32 carDetails_,
        address applicant_
    ) external {
        vm.assume(
            applicant_ != address(0) &&
                disallowedApplicants[applicant_] == false
        );
        value_ = bound(
            value_,
            insuranceManager.MIN_VALUE(),
            insuranceManager.MAX_VALUE()
        );

        vm.startPrank(applicant_);
        vm.expectEmit(true, true, false, true);
        emit InsuranceManager.ApplicationSubmitted(
            insuranceManager.nextApplicationId(),
            applicant_,
            value_
        );
        uint256 _applicationId = insuranceManager.submitApplication(
            value_,
            carDetails_
        );
        vm.stopPrank();

        (
            address _applicant,
            uint256 _tokenId,
            uint256 _value,
            uint256 _riskFactor,
            uint256 _submissionTimestamp,
            uint256 _reviewTimestamp,
            uint256 _premium,
            bytes32 _carDetails,
            bool _isPaid,
            InsuranceManager.ApplicationStatus _status
        ) = insuranceManager.applications(_applicationId);

        assertEq(_applicant, applicant_);
        assertEq(_tokenId, 0);
        assertEq(_value, value_);
        assertEq(_riskFactor, 0);
        assertEq(_submissionTimestamp, block.timestamp);
        assertEq(_reviewTimestamp, 0);
        assertEq(_premium, 0);
        assertEq(_carDetails, carDetails_);
        assertEq(_isPaid, false);
        assertTrue(_status == InsuranceManager.ApplicationStatus.Pending);
    }

    function test_submitApplication_fail_notInitialized(
        uint256 value_,
        bytes32 carDetails_,
        address applicant_
    ) external {
        vm.assume(
            applicant_ != address(0) &&
                disallowedApplicants[applicant_] == false
        );
        value_ = bound(
            value_,
            insuranceManager.MIN_VALUE(),
            insuranceManager.MAX_VALUE()
        );
        _disableAdjuster(adjusterAdmins[0]);

        vm.startPrank(applicant_);
        vm.expectRevert(
            InsuranceManager.InsuranceManager_NotInitialized.selector
        );
        insuranceManager.submitApplication(value_, carDetails_);
        vm.stopPrank();
    }

    function test_submitApplication_fail_invalidValue(
        uint256 value_,
        bytes32 carDetails_,
        address applicant_
    ) external {
        vm.assume(
            applicant_ != address(0) &&
                disallowedApplicants[applicant_] == false
        );
        vm.assume(
            value_ == insuranceManager.MIN_VALUE() - 1 ||
                value_ > insuranceManager.MAX_VALUE()
        );

        vm.startPrank(applicant_);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsuranceManager.InsuranceManager_InvalidValue.selector,
                value_
            )
        );
        insuranceManager.submitApplication(value_, carDetails_);
        vm.stopPrank();
    }

    function test_submitApplication_fail_invalidCarDetails(
        uint256 value_,
        bytes32 carDetails_,
        address applicant1_,
        address applicant2_
    ) external {
        vm.assume(
            applicant1_ != address(0) &&
                disallowedApplicants[applicant1_] == false &&
                disallowedApplicants[applicant2_] == false &&
                applicant1_ != applicant2_
        );
        value_ = bound(
            value_,
            insuranceManager.MIN_VALUE(),
            insuranceManager.MAX_VALUE()
        );

        vm.startPrank(applicant1_);
        insuranceManager.submitApplication(value_, carDetails_);
        vm.stopPrank();

        vm.startPrank(applicant2_);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsuranceManager.InsuranceManager_InvalidCarDetails.selector,
                carDetails_
            )
        );
        insuranceManager.submitApplication(value_, carDetails_);
        vm.stopPrank();
    }

    function test_reviewApplication_success_approved(
        uint256 riskFactor_
    ) external {
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Approved;
        vm.startPrank(adjusterAdmins[0]);
        vm.expectEmit(true, false, false, true);
        emit InsuranceManager.ApplicationReviewed(_applicationId, _status0);
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();
        (
            ,
            ,
            ,
            uint256 _riskFactor1,
            ,
            uint256 _reviewTimestamp1,
            uint256 _premium1,
            ,
            bool _isPaid1,

        ) = insuranceManager.applications(_applicationId);

        assertEq(_riskFactor1, riskFactor_, "riskFactor mismatch");
        assertEq(
            _reviewTimestamp1,
            block.timestamp,
            "reviewTimestamp mismatch"
        );
        assertEq(
            _premium1,
            insuranceManager.calculatePremium(_value0, riskFactor_),
            "premium mismatch"
        );
        assertEq(_isPaid1, false, "isPaid mismatch");
    }

    function test_reviewApplication_success_rejected(
        uint256 riskFactor_
    ) external {
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Rejected;
        vm.startPrank(adjusterAdmins[0]);
        vm.expectEmit(true, false, false, true);
        emit InsuranceManager.ApplicationReviewed(_applicationId, _status0);
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();
        (
            address _applicant1,
            uint256 _tokenId,
            uint256 _value1,
            uint256 _riskFactor1,
            ,
            uint256 _reviewTimestamp1,
            uint256 _premium1,
            bytes32 _carDetails1,
            bool _isPaid1,
            InsuranceManager.ApplicationStatus _status1
        ) = insuranceManager.applications(_applicationId);

        assertEq(_applicant1, _applicant0, "applicant mismatch");
        assertEq(_tokenId, 0, "tokenId mismatch");
        assertEq(_value1, _value0, "value mismatch");
        assertEq(_riskFactor1, 0, "riskFactor mismatch");
        assertEq(
            _reviewTimestamp1,
            block.timestamp,
            "reviewTimestamp mismatch"
        );
        assertEq(_premium1, 0, "premium mismatch");
        assertEq(_carDetails1, _carDetails0, "carDetails mismatch");
        assertEq(_isPaid1, false, "isPaid mismatch");
        assertTrue(_status1 == _status0, "status mismatch");
    }

    function test_reviewApplication_fail_invalidAdjuster(
        uint256 riskFactor_,
        address nonAdjuster_
    ) external {
        vm.assume(
            nonAdjuster_ != address(0) &&
                disallowedApplicants[nonAdjuster_] == false
        );
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Rejected;
        vm.startPrank(nonAdjuster_);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsuranceManager.InsuranceManager_InvalidAdjuster.selector,
                nonAdjuster_
            )
        );
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();
    }

    function test_reviewApplication_fail_invalidNewStatus(
        uint256 riskFactor_
    ) external {
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Pending;
        vm.startPrank(adjusterAdmins[0]);
        vm.expectRevert(
            InsuranceManager.InsuranceManager_InvalidApplicationStatus.selector
        );
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();
    }

    function test_reviewApplication_fail_invalidNewStatusClaimed(
        uint256 riskFactor_
    ) external {
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Claimed;
        vm.startPrank(adjusterAdmins[0]);
        vm.expectRevert(
            InsuranceManager.InsuranceManager_InvalidApplicationStatus.selector
        );
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();
    }

    function test_reviewApplication_fail_invalidCurrentStatus(
        uint256 riskFactor_
    ) external {
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Rejected;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.expectRevert(
            InsuranceManager.InsuranceManager_InvalidApplicationStatus.selector
        );
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();
    }

    function test_activatePolicy_success(
        uint256 riskFactor_,
        uint256 numSeconds_
    ) external {
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        numSeconds_ = bound(
            numSeconds_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Approved;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();

        (, , , , , , uint256 _premium1, , , ) = insuranceManager.applications(
            _applicationId
        );

        uint256 _amount = (numSeconds_ * _premium1);
        vm.startPrank(_applicant0);
        mockToken.mint(_applicant0, _amount);
        mockToken.approve(address(insuranceManager), _amount);
        vm.expectEmit(true, false, false, false);
        emit InsuranceManager.PolicyActivated(_applicationId);
        insuranceManager.activatePolicy(_applicationId, _amount);
        vm.stopPrank();

        (, uint256 _tokenId, , , , , , , bool _isPaid, ) = insuranceManager
            .applications(_applicationId);
        assertTrue(_isPaid);
        assertEq(_applicant0, insuranceCoverageNFT.ownerOf(_tokenId));
    }

    function test_activatePolicy_fail_invalidApplicationStatus(
        uint256 riskFactor_,
        uint256 numSeconds_
    ) external {
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        numSeconds_ = bound(
            numSeconds_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Rejected;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();

        (, , , , , , uint256 _premium1, , , ) = insuranceManager.applications(
            _applicationId
        );

        uint256 _amount = (numSeconds_ * _premium1);
        vm.startPrank(_applicant0);
        vm.expectRevert(
            InsuranceManager.InsuranceManager_InvalidApplicationStatus.selector
        );
        insuranceManager.activatePolicy(_applicationId, _amount);
        vm.stopPrank();
    }

    function test_activatePolicy_fail_invalidApplicationStatusTimeWindow(
        uint256 riskFactor_,
        uint256 numSeconds_
    ) external {
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        numSeconds_ = bound(
            numSeconds_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Approved;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();

        (, , , , , , uint256 _premium1, , , ) = insuranceManager.applications(
            _applicationId
        );

        skip(insuranceManager.MAX_TIME_WINDOW() + 1);
        uint256 _amount = (numSeconds_ * _premium1);
        vm.startPrank(_applicant0);
        vm.expectRevert(
            InsuranceManager.InsuranceManager_InvalidApplicationStatus.selector
        );
        insuranceManager.activatePolicy(_applicationId, _amount);
        vm.stopPrank();
    }

    function test_extendCoverage_success(
        uint256 riskFactor_,
        uint256 numSeconds_,
        address extender_
    ) public {
        vm.assume(extender_ != address(0));
        riskFactor_ = bound(riskFactor_, 1, insuranceManager.MAX_RISK_FACTOR());
        numSeconds_ = bound(
            numSeconds_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION() - 1
        );
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Approved;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            riskFactor_,
            _status0
        );
        vm.stopPrank();

        (, , , , , , uint256 _premium1, , , ) = insuranceManager.applications(
            _applicationId
        );

        uint256 _amount = (numSeconds_ * _premium1);
        vm.startPrank(_applicant0);
        mockToken.mint(_applicant0, _amount);
        mockToken.approve(address(insuranceManager), _amount);
        insuranceManager.activatePolicy(_applicationId, _amount);
        vm.stopPrank();

        (, uint256 _tokenId, , , , , , , , ) = insuranceManager.applications(
            _applicationId
        );

        (, , , uint256 endTime, ) = insuranceCoverageNFT.policyDetails(
            _tokenId
        );

        uint256 _extensionTime = insuranceCoverageNFT.MAX_COVERAGE_DURATION() -
            (endTime - block.timestamp);
        uint256 _newAmount = (_extensionTime * _premium1);

        vm.startPrank(extender_);
        mockToken.mint(extender_, _newAmount);
        mockToken.approve(address(insuranceManager), _newAmount);
        insuranceManager.extendCoverage(_applicationId, _newAmount);
        vm.stopPrank();
    }

    function _depositForYield(uint256 amount_) internal {
        vm.startPrank(yieldManager.managerContract());
        mockToken.mint(address(yieldManager), amount_);
        yieldManager.deposit(amount_);
        vm.stopPrank();
    }

    function test_claimPolicy_success() external {
        uint256 _riskFactor = 10;
        uint256 _numSeconds = 10000;
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Approved;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            _riskFactor,
            _status0
        );
        vm.stopPrank();

        (, , uint256 _value1, , , , uint256 _premium1, , , ) = insuranceManager
            .applications(_applicationId);

        _depositForYield(_value1);

        uint256 _amount = (_numSeconds * _premium1);
        vm.startPrank(_applicant0);
        mockToken.mint(_applicant0, _amount);
        mockToken.approve(address(insuranceManager), _amount);
        insuranceManager.activatePolicy(_applicationId, _amount);
        vm.expectEmit(true, false, false, false);
        emit InsuranceManager.PolicyClaimed(_applicationId);
        insuranceManager.claimPolicy(_applicationId);
        vm.stopPrank();

        assertEq(
            mockToken.balanceOf(_applicant0),
            _value1,
            "applicant balance mismatch"
        );

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            InsuranceManager.ApplicationStatus _status
        ) = insuranceManager.applications(_applicationId);
        assertTrue(_status == InsuranceManager.ApplicationStatus.Claimed);
    }

    function test_claimPolicy_fail_insufficientFunds() external {
        uint256 _riskFactor = 10;
        uint256 _numSeconds = 10000;
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Approved;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            _riskFactor,
            _status0
        );
        vm.stopPrank();

        (, , , , , , uint256 _premium1, , , ) = insuranceManager.applications(
            _applicationId
        );

        uint256 _amount = (_numSeconds * _premium1);
        vm.startPrank(_applicant0);
        mockToken.mint(_applicant0, _amount);
        mockToken.approve(address(insuranceManager), _amount);

        insuranceManager.activatePolicy(_applicationId, _amount);
        vm.expectRevert(
            InsuranceManager.InsuranceManager_InsufficientFunds.selector
        );
        insuranceManager.claimPolicy(_applicationId);
        vm.stopPrank();
    }

    function test_claimPolicy_fail_invalidClaimant() external {
        uint256 _riskFactor = 10;
        uint256 _numSeconds = 10000;
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Approved;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            _riskFactor,
            _status0
        );
        vm.stopPrank();

        (, , , , , , uint256 _premium1, , , ) = insuranceManager.applications(
            _applicationId
        );

        uint256 _amount = (_numSeconds * _premium1);
        vm.startPrank(_applicant0);
        mockToken.mint(_applicant0, _amount);
        mockToken.approve(address(insuranceManager), _amount);

        insuranceManager.activatePolicy(_applicationId, _amount);

        vm.stopPrank();
        address _applicant1 = vm.addr(getCounterAndIncrement());
        vm.startPrank(_applicant1);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsuranceManager.InsuranceManager_InvalidClaimant.selector,
                _applicant1
            )
        );
        insuranceManager.claimPolicy(_applicationId);
        vm.stopPrank();
    }

    function test_claimPolicy_fail_invalidApplicationStatus() external {
        uint256 _riskFactor = 10;
        uint256 _numSeconds = 10000;
        address _applicant0 = vm.addr(getCounterAndIncrement());
        uint256 _value0 = 100e18;
        bytes32 _carDetails0 = bytes32("carDetails");
        uint256 _applicationId = _createPendingApplication(
            _value0,
            _carDetails0,
            _applicant0
        );

        InsuranceManager.ApplicationStatus _status0 = InsuranceManager
            .ApplicationStatus
            .Approved;
        vm.startPrank(adjusterAdmins[0]);
        insuranceManager.reviewApplication(
            _applicationId,
            _riskFactor,
            _status0
        );
        vm.stopPrank();

        (, , , , , , uint256 _premium1, , , ) = insuranceManager.applications(
            _applicationId
        );

        uint256 _amount = (_numSeconds * _premium1);
        vm.startPrank(_applicant0);
        mockToken.mint(_applicant0, _amount);
        mockToken.approve(address(insuranceManager), _amount);

        insuranceManager.activatePolicy(_applicationId, _amount);

        _depositForYield(_value0);

        vm.stopPrank();
        vm.startPrank(_applicant0);
        insuranceManager.claimPolicy(_applicationId);
        vm.expectRevert(
            InsuranceManager.InsuranceManager_InvalidApplicationStatus.selector
        );
        insuranceManager.claimPolicy(_applicationId);
        vm.stopPrank();
    }
}
