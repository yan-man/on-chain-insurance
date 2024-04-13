// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {DeployInsuranceRegistry} from "../../script/DeployInsuranceRegistry.s.sol";
import {InsuranceRegistry} from "../../contracts/InsuranceRegistry.sol";

contract InsuranceRegistryTest is Test {
    DeployInsuranceRegistry public deployInsuranceRegistry;
    DeployInsuranceRegistry.InsuranceRegistryArgs public args;
    InsuranceRegistry public insuranceRegistry;

    function setUp() external {
        deployInsuranceRegistry = new DeployInsuranceRegistry();

        address _masterAdmin = address(this);
        args = DeployInsuranceRegistry.InsuranceRegistryArgs(_masterAdmin);
        deployInsuranceRegistry.setConstructorArgs(args);

        insuranceRegistry = deployInsuranceRegistry.run();
    }

    function test_deploymentParams() external view {
        assertTrue(
            insuranceRegistry.hasRole(
                insuranceRegistry.MASTER_ADMIN(),
                args.masterAdmin
            )
        );
    }
}
