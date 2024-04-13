// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CustomTest} from "../helpers/CustomTest.t.sol";

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

    function test_deploymentParams_success() external view {
        assertTrue(
            insuranceRegistry.hasRole(
                insuranceRegistry.MASTER_ADMIN(),
                args.masterAdmin
            )
        );
    }

    function test_addApprover_fail_nonMasterAdmin(
        address nonMasterAdmin_
    ) external {
        vm.assume(nonMasterAdmin_ != args.masterAdmin);
        address _approver = vm.addr(getCounterAndIncrement());
        vm.startPrank(nonMasterAdmin_);
        vm.expectRevert(
            InsuranceRegistry.InsuranceRegistry_OnlyMasterAdmin.selector
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

    function test_addApprover_success(address approver_) external {
        vm.assume(approver_ != args.masterAdmin);
        vm.startPrank(args.masterAdmin);
        insuranceRegistry.addApprover(approver_);
        vm.stopPrank();
        assertTrue(
            insuranceRegistry.hasRole(
                insuranceRegistry.APPROVER_ADMIN(),
                approver_
            )
        );
    }
}
