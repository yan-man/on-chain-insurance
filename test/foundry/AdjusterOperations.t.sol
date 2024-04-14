// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {CustomTest} from "../helpers/CustomTest.t.sol";
import {Test, console} from "forge-std/Test.sol";

import {DeployAdjusterOperations} from "../../script/DeployAdjusterOperations.s.sol";
import {AdjusterOperations} from "../../contracts/AdjusterOperations.sol";

contract AdjusterOperationsTest is Test, CustomTest {
    DeployAdjusterOperations public deployAdjusterOperations;
    DeployAdjusterOperations.AdjusterOperationsArgs public args;
    AdjusterOperations public adjusterOperations;

    function setUp() external {
        deployAdjusterOperations = new DeployAdjusterOperations();

        address _masterAdmin = vm.addr(getCounterAndIncrement());
        args = DeployAdjusterOperations.AdjusterOperationsArgs({
            masterAdmin: _masterAdmin
        });
        deployAdjusterOperations.setConstructorArgs(args);

        adjusterOperations = deployAdjusterOperations.run();
    }

    function _addApprover(address approver_) internal {
        vm.startPrank(args.masterAdmin);
        adjusterOperations.addApprover(approver_);
        vm.stopPrank();
    }

    function test_deploymentParams_success() external view {
        assertTrue(
            adjusterOperations.hasRole(
                adjusterOperations.MASTER_ADMIN(),
                args.masterAdmin
            )
        );
        assertEq(adjusterOperations.adjusterCount(), 0);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_addApprover_success(address approver_) external {
        vm.assume(approver_ != args.masterAdmin && approver_ != address(0));
        vm.startPrank(args.masterAdmin);
        vm.expectEmit(true, true, true, false);
        emit IAccessControl.RoleGranted(
            adjusterOperations.APPROVER_ADMIN(),
            approver_,
            args.masterAdmin
        );
        adjusterOperations.addApprover(approver_);
        vm.stopPrank();
        assertTrue(
            adjusterOperations.hasRole(
                adjusterOperations.APPROVER_ADMIN(),
                approver_
            )
        );
        assertEq(adjusterOperations.adjusterCount(), 0);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_addApprover_fail_invalidMasterAdmin(
        address nonMasterAdmin_
    ) external {
        vm.assume(nonMasterAdmin_ != args.masterAdmin);
        address _approver = vm.addr(getCounterAndIncrement());
        vm.startPrank(nonMasterAdmin_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonMasterAdmin_,
                adjusterOperations.MASTER_ADMIN()
            )
        );
        adjusterOperations.addApprover(_approver);
        vm.stopPrank();
        assertEq(adjusterOperations.adjusterCount(), 0);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_addApprover_fail_invalidApprover() external {
        vm.startPrank(args.masterAdmin);
        vm.expectRevert(
            AdjusterOperations.AdjusterOperations_InvalidApprover.selector
        );
        adjusterOperations.addApprover(args.masterAdmin);
        vm.stopPrank();
        assertEq(adjusterOperations.adjusterCount(), 0);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_addApprover_fail_invalidZeroAddress() external {
        address _approver = address(0);
        vm.startPrank(args.masterAdmin);
        vm.expectRevert(
            AdjusterOperations.AdjusterOperations_InvalidZeroAddress.selector
        );
        adjusterOperations.addApprover(_approver);
        vm.stopPrank();
        assertFalse(
            adjusterOperations.hasRole(
                adjusterOperations.APPROVER_ADMIN(),
                _approver
            )
        );
        assertEq(adjusterOperations.adjusterCount(), 0);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_removeApprover_success(address approver_) external {
        vm.assume(approver_ != args.masterAdmin && approver_ != address(0));
        vm.startPrank(args.masterAdmin);
        adjusterOperations.addApprover(approver_);
        adjusterOperations.removeApprover(approver_);
        vm.stopPrank();
        assertFalse(
            adjusterOperations.hasRole(
                adjusterOperations.APPROVER_ADMIN(),
                approver_
            )
        );
        assertEq(adjusterOperations.adjusterCount(), 0);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_removeApprover_fail_invalidMasterAdmin(
        address nonMasterAdmin_,
        address approver_
    ) external {
        vm.assume(nonMasterAdmin_ != args.masterAdmin);
        vm.assume(approver_ != args.masterAdmin && approver_ != address(0));

        vm.startPrank(args.masterAdmin);
        adjusterOperations.addApprover(approver_);
        vm.stopPrank();

        vm.startPrank(nonMasterAdmin_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonMasterAdmin_,
                adjusterOperations.MASTER_ADMIN()
            )
        );
        adjusterOperations.removeApprover(approver_);
        vm.stopPrank();
        assertEq(adjusterOperations.adjusterCount(), 0);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_setInsuranceAdjuster_success_initialize(
        address approver_,
        address adjuster_
    ) external {
        vm.assume(
            adjuster_ != address(0) &&
                adjuster_ != args.masterAdmin &&
                adjuster_ != approver_
        );
        vm.assume(approver_ != address(0) && approver_ != args.masterAdmin);
        bool _status = true;
        _addApprover(approver_);
        vm.startPrank(approver_);
        vm.expectEmit(true, true, false, false);
        emit AdjusterOperations.AdjusterOperations_AdjustersUpdated(
            adjuster_,
            _status
        );
        adjusterOperations.setInsuranceAdjuster(adjuster_, _status);
        vm.stopPrank();
        assertEq(adjusterOperations.isAdjuster(adjuster_), _status);
        assertEq(adjusterOperations.adjusterCount(), 1);
        (address _adjuster, ) = adjusterOperations.adjusters(adjuster_);
        assertEq(_adjuster, adjuster_);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_setInsuranceAdjuster_success_editStatus(
        address approver_,
        address adjuster_,
        bool status_
    ) external {
        vm.assume(
            adjuster_ != address(0) &&
                adjuster_ != args.masterAdmin &&
                adjuster_ != approver_
        );
        vm.assume(approver_ != address(0) && approver_ != args.masterAdmin);

        // initialize adjuster
        _addApprover(approver_);
        vm.startPrank(approver_);
        adjusterOperations.setInsuranceAdjuster(adjuster_, status_);
        bool _newStatus = !status_;
        adjusterOperations.setInsuranceAdjuster(adjuster_, _newStatus);
        vm.stopPrank();

        assertEq(adjusterOperations.isAdjuster(adjuster_), _newStatus);
        assertEq(adjusterOperations.adjusterCount(), _newStatus ? 1 : 0);
        (address _adjuster, ) = adjusterOperations.adjusters(adjuster_);
        assertEq(_adjuster, adjuster_);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_setInsuranceAdjuster_fail_invalidApproverAdmin(
        address nonApproverAdmin_,
        address adjuster_,
        bool status_
    ) external {
        vm.assume(
            adjuster_ != address(0) &&
                adjuster_ != args.masterAdmin &&
                adjuster_ != nonApproverAdmin_
        );

        vm.startPrank(nonApproverAdmin_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonApproverAdmin_,
                adjusterOperations.APPROVER_ADMIN()
            )
        );
        adjusterOperations.setInsuranceAdjuster(adjuster_, status_);
        vm.stopPrank();
        assertEq(adjusterOperations.isAdjuster(adjuster_), false);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_setInsuranceAdjuster_fail_invalidZeroAddress(
        address approverAdmin_,
        bool status_
    ) external {
        vm.assume(
            approverAdmin_ != address(0) && approverAdmin_ != args.masterAdmin
        );
        address _adjuster = address(0);
        _addApprover(approverAdmin_);

        vm.startPrank(approverAdmin_);
        vm.expectRevert(
            AdjusterOperations.AdjusterOperations_InvalidZeroAddress.selector
        );
        adjusterOperations.setInsuranceAdjuster(_adjuster, status_);
        vm.stopPrank();
        assertEq(adjusterOperations.isAdjuster(_adjuster), false);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_setInsuranceAdjuster_fail_invalidAdjuster(
        address approverAdmin_,
        bool status_
    ) external {
        vm.assume(
            approverAdmin_ != address(0) && approverAdmin_ != args.masterAdmin
        );
        address _adjuster = approverAdmin_;
        _addApprover(approverAdmin_);
        vm.startPrank(approverAdmin_);
        vm.expectRevert(
            AdjusterOperations.AdjusterOperations_InvalidAdjuster.selector
        );
        adjusterOperations.setInsuranceAdjuster(_adjuster, status_);
        vm.stopPrank();
        assertEq(adjusterOperations.isAdjuster(_adjuster), false);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_setInsuranceAdjuster_fail_invalidAdjusterMasterAdmin(
        address approverAdmin_,
        bool status_
    ) external {
        vm.assume(
            approverAdmin_ != address(0) && approverAdmin_ != args.masterAdmin
        );
        address _adjuster = args.masterAdmin;

        _addApprover(approverAdmin_);
        vm.startPrank(approverAdmin_);
        vm.expectRevert(
            AdjusterOperations.AdjusterOperations_InvalidAdjuster.selector
        );
        adjusterOperations.setInsuranceAdjuster(_adjuster, status_);
        vm.stopPrank();
        assertEq(adjusterOperations.isAdjuster(_adjuster), false);
        assertFalse(adjusterOperations.isInitialized());
    }

    function test_isInitialized_success() external {
        address _approver = vm.addr(getCounterAndIncrement());
        _addApprover(_approver);
        uint256 _expectedApproverCount = adjusterOperations
            .REQUIRED_APPROVERS();
        assertEq(
            adjusterOperations.getRoleMemberCount(
                adjusterOperations.APPROVER_ADMIN()
            ),
            _expectedApproverCount
        );

        uint256 _expectedAdjusterCount = adjusterOperations
            .REQUIRED_ADJUSTERS();
        address _adjuster;
        bool _status = true;
        vm.startPrank(_approver);
        for (uint256 i = _expectedAdjusterCount; i > 0; --i) {
            _adjuster = vm.addr(getCounterAndIncrement());
            adjusterOperations.setInsuranceAdjuster(_adjuster, _status);
            assertEq(adjusterOperations.isAdjuster(_adjuster), _status);
        }

        assertTrue(adjusterOperations.isInitialized());
    }
}
