// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {InsuranceManager} from "../contracts/InsuranceManager.sol";

/// @title Script to deploy InsuranceManager contract
contract DeployInsuranceManager is Script {
    struct InsuranceManagerArgs {
        address adjusterOperationsAddress;
        address paymentTokenAddress;
        address poolAddress;
    }
    InsuranceManagerArgs public args;
    InsuranceManager public insuranceManager;

    function run() external returns (InsuranceManager) {
        vm.startBroadcast();
        insuranceManager = new InsuranceManager(
            args.adjusterOperationsAddress,
            args.paymentTokenAddress,
            args.poolAddress
        );
        vm.stopBroadcast();
        return insuranceManager;
    }

    function setConstructorArgs(InsuranceManagerArgs calldata args_) external {
        args = args_;
    }
}
