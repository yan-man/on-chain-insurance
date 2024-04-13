// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {CustomTest} from "../helpers/CustomTest.t.sol";
import {Test, console} from "forge-std/Test.sol";

import {DeployInsuranceRegistry} from "../../script/DeployInsuranceRegistry.s.sol";
import {InsuranceRegistry} from "../../contracts/InsuranceRegistry.sol";

contract InsuranceRegistryTest is Test, CustomTest {
    DeployInsuranceRegistry public deployInsuranceRegistry;
    DeployInsuranceRegistry.InsuranceRegistryArgs public args;
    InsuranceRegistry public insuranceRegistry;

    function setUp() external {
        deployInsuranceRegistry = new DeployInsuranceRegistry();

        address _masterAdmin = vm.addr(getCounterAndIncrement());
        args = DeployInsuranceRegistry.InsuranceRegistryArgs(_masterAdmin);
        deployInsuranceRegistry.setConstructorArgs(args);

        insuranceRegistry = deployInsuranceRegistry.run();
    }

    function _addApprover(address approver_) internal {
        vm.startPrank(args.masterAdmin);
        insuranceRegistry.addApprover(approver_);
        vm.stopPrank();
    }

    function test_deploymentParams_success() external view {
        assertTrue(
            insuranceRegistry.hasRole(
                insuranceRegistry.MASTER_ADMIN(),
                args.masterAdmin
            )
        );
    }

    function test_addApprover_success(address approver_) external {
        vm.assume(approver_ != args.masterAdmin && approver_ != address(0));
        vm.startPrank(args.masterAdmin);
        vm.expectEmit(true, true, true, false);
        emit IAccessControl.RoleGranted(
            insuranceRegistry.APPROVER_ADMIN(),
            approver_,
            args.masterAdmin
        );
        insuranceRegistry.addApprover(approver_);
        vm.stopPrank();
        console.log(
            insuranceRegistry.hasRole(
                insuranceRegistry.APPROVER_ADMIN(),
                approver_
            )
        );
        assertTrue(
            insuranceRegistry.hasRole(
                insuranceRegistry.APPROVER_ADMIN(),
                approver_
            )
        );
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
                insuranceRegistry.MASTER_ADMIN()
            )
        );
        insuranceRegistry.addApprover(_approver);
        vm.stopPrank();
    }

    function test_addApprover_fail_invalidApprover() external {
        vm.startPrank(args.masterAdmin);
        vm.expectRevert(
            InsuranceRegistry.InsuranceRegistry_InvalidApprover.selector
        );
        insuranceRegistry.addApprover(args.masterAdmin);
        vm.stopPrank();
    }

    function test_addApprover_fail_invalidZeroAddress() external {
        address _approver = address(0);
        vm.startPrank(args.masterAdmin);
        vm.expectRevert(
            InsuranceRegistry.InsuranceRegistry_InvalidZeroAddress.selector
        );
        insuranceRegistry.addApprover(_approver);
        vm.stopPrank();
    }

    function test_removeApprover_success(address approver_) external {
        vm.assume(approver_ != args.masterAdmin);
        vm.startPrank(args.masterAdmin);
        insuranceRegistry.addApprover(approver_);
        insuranceRegistry.removeApprover(approver_);
        vm.stopPrank();
        assertFalse(
            insuranceRegistry.hasRole(
                insuranceRegistry.APPROVER_ADMIN(),
                approver_
            )
        );
    }

    function test_removeApprover_fail_invalidMasterAdmin(
        address nonMasterAdmin_,
        address approver_
    ) external {
        vm.assume(
            nonMasterAdmin_ != args.masterAdmin &&
                approver_ != args.masterAdmin &&
                approver_ != address(0)
        );

        vm.startPrank(args.masterAdmin);
        insuranceRegistry.addApprover(approver_);
        vm.stopPrank();

        vm.startPrank(nonMasterAdmin_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonMasterAdmin_,
                insuranceRegistry.MASTER_ADMIN()
            )
        );
        insuranceRegistry.removeApprover(approver_);
        vm.stopPrank();
    }

    function test_setInsuranceAdjuster_success(
        address adjuster_,
        bool status_
    ) external {
        address _approver = vm.addr(getCounterAndIncrement());
        vm.assume(
            adjuster_ != address(0) &&
                adjuster_ != args.masterAdmin &&
                adjuster_ != _approver
        );
        _addApprover(_approver);
        vm.startPrank(_approver);
        vm.expectEmit(true, true, false, false);
        emit InsuranceRegistry.InsuranceRegistry_AdjustersUpdated(
            adjuster_,
            status_
        );
        insuranceRegistry.setInsuranceAdjuster(adjuster_, status_);
        vm.stopPrank();
    }

    function test_setInsuranceAdjuster_fail_invalidApproverAdmin(
        address nonApproverAdmin_,
        address adjuster_,
        bool status_
    ) external {
        vm.startPrank(nonApproverAdmin_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonApproverAdmin_,
                insuranceRegistry.APPROVER_ADMIN()
            )
        );
        insuranceRegistry.setInsuranceAdjuster(adjuster_, status_);
        vm.stopPrank();
    }
}
