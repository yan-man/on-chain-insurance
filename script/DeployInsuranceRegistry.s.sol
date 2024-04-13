// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {InsuranceRegistry} from "../contracts/InsuranceRegistry.sol";

/// @title Script to deploy InsuranceRegistry contract
contract DeployInsuranceRegistry is Script {
    struct InsuranceRegistryArgs {
        address masterAdmin;
    }
    InsuranceRegistryArgs public args;
    InsuranceRegistry public insuranceRegistry;

    function run() external returns (InsuranceRegistry) {
        vm.startBroadcast();
        insuranceRegistry = new InsuranceRegistry(args.masterAdmin);
        vm.stopBroadcast();
        return insuranceRegistry;
    }

    function setConstructorArgs(InsuranceRegistryArgs calldata args_) external {
        args = args_;
    }
}
