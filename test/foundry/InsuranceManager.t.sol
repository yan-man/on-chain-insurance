// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
// import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {CustomTest} from "../helpers/CustomTest.t.sol";
import {Test, console} from "forge-std/Test.sol";

// import {DeployInsuranceCoverageNFT} from "../../script/DeployInsuranceCoverageNFT.s.sol";
import {DeployAdjusterOperations} from "../../script/DeployAdjusterOperations.s.sol";
import {DeployInsuranceManager} from "../../script/DeployInsuranceManager.s.sol";

import {AdjusterOperations} from "../../contracts/AdjusterOperations.sol";
import {InsuranceCoverageNFT} from "../../contracts/InsuranceCoverageNFT.sol";
import {InsuranceManager} from "../../contracts/InsuranceManager.sol";
import {SampleERC20} from "../../contracts/mocks/SampleERC20.sol";

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
    SampleERC20 public sampleERC20;
    address public masterAdmin;
    address[] public approverAdmins;
    address[] public adjusterAdmins;

    function setUp() external {
        masterAdmin = vm.addr(getCounterAndIncrement());

        DeployAdjusterOperations deployAdjusterOperations = new DeployAdjusterOperations();
        deployAdjusterOperations.setConstructorArgs(
            DeployAdjusterOperations.AdjusterOperationsArgs({
                masterAdmin: masterAdmin
            })
        );
        adjusterOperations = deployAdjusterOperations.run();

        sampleERC20 = new SampleERC20();

        deployInsuranceManager = new DeployInsuranceManager();
        args = DeployInsuranceManager.InsuranceManagerArgs({
            adjusterOperationsAddress: address(adjusterOperations),
            paymentTokenAddress: address(sampleERC20)
        });
        deployInsuranceManager.setConstructorArgs(args);

        insuranceManager = deployInsuranceManager.run();
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
        }
        vm.stopPrank();
        vm.startPrank(_approverAdmin);
        uint256 numAdjusters = adjusterOperations.REQUIRED_ADJUSTERS();
        address _adjusterAdmin;
        for (uint256 i = numAdjusters; i > 0; --i) {
            _adjusterAdmin = vm.addr(getCounterAndIncrement());
            adjusterOperations.setInsuranceAdjuster(_adjusterAdmin, true);
            adjusterAdmins.push(_adjusterAdmin);
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
    ) internal {
        vm.startPrank(applicant_);
        insuranceManager.submitApplication(value_, carDetails_);
        vm.stopPrank();
    }

    function test_deploymentParams_success() external view {
        assertTrue(adjusterOperations.isInitialized());
        assertEq(
            address(insuranceManager.adjusterOperations()),
            address(adjusterOperations)
        );
        assertEq(
            address(insuranceManager.paymentToken()),
            address(sampleERC20)
        );
        assertEq(insuranceManager.insuranceNFT().name(), "InsuranceCoverage");
        assertEq(insuranceManager.insuranceNFT().symbol(), "ICNFT");
    }

    function test_submitApplication_success(
        uint256 value_,
        bytes32 carDetails_,
        address applicant_
    ) external {
        vm.assume(applicant_ != address(0));
        value_ = bound(value_, 1, insuranceManager.MAX_VALUE());
        _setUpAdjusterOperations();

        uint256 _applicationId = insuranceManager.nextApplicationId();
        vm.startPrank(applicant_);
        vm.expectEmit(true, true, false, true);
        emit InsuranceManager.ApplicationSubmitted(
            insuranceManager.nextApplicationId(),
            applicant_,
            value_
        );
        insuranceManager.submitApplication(value_, carDetails_);
        vm.stopPrank();

        (
            address _applicant,
            uint256 _value,
            uint256 _riskFactor,
            uint256 _submissionTimestamp,
            uint256 _premium,
            bytes32 _carDetails,
            bool _isPaid,
            InsuranceManager.ApplicationStatus _status
        ) = insuranceManager.applications(_applicationId);

        assertEq(_applicant, applicant_);
        assertEq(
            _value,
            value_ * (10 ** ERC20(address(sampleERC20)).decimals())
        );
        assertEq(_riskFactor, 0);
        assertEq(_submissionTimestamp, block.timestamp);
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
        vm.assume(applicant_ != address(0));
        value_ = bound(value_, 1, insuranceManager.MAX_VALUE());
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
        vm.assume(applicant_ != address(0));
        vm.assume(value_ == 0 || value_ > insuranceManager.MAX_VALUE());

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
        vm.assume(applicant1_ != address(0) && applicant1_ != applicant2_);
        value_ = bound(value_, 1, insuranceManager.MAX_VALUE());

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

    function test_reviewApplication_success(
        uint256 riskFactor_,
        InsuranceManager.ApplicationStatus status_
    ) external {
        // vm.assume(
        //     applicationId_ < insuranceManager.nextApplicationId() &&
        //         status_ != InsuranceManager.ApplicationStatus.Pending
        // );
        // _createPendingApplication();
        // vm.startPrank(approverAdmins[0]);
        // vm.expectEmit(true, true, false, true);
        // emit InsuranceManager.ApplicationReviewed(applicationId_, status_);
        // insuranceManager.reviewApplication(
        //     applicationId_,
        //     riskFactor_,
        //     status_
        // );
        // vm.stopPrank();
        // (
        //     address _applicant,
        //     uint256 _value,
        //     uint256 _riskFactor,
        //     uint256 _submissionTimestamp,
        //     uint256 _premium,
        //     bytes32 _carDetails,
        //     bool _isPaid,
        //     InsuranceManager.ApplicationStatus _status
        // ) = insuranceManager.applications(applicationId_);
        // assertEq(_status, status_);
        // if (status_ == InsuranceManager.ApplicationStatus.Approved) {
        //     assertEq(_riskFactor, riskFactor_);
        // }
    }
}
