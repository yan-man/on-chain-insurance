// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AdjusterOperations} from "../contracts/AdjusterOperations.sol";

/// @title Script to deploy AdjusterOperations contract
contract DeployAdjusterOperations is Script {
    struct AdjusterOperationsArgs {
        address masterAdmin;
    }
    AdjusterOperationsArgs public args;
    AdjusterOperations public adjusterOperations;

    function run() external returns (AdjusterOperations) {
        vm.startBroadcast();
        adjusterOperations = new AdjusterOperations(args.masterAdmin);
        vm.stopBroadcast();
        return adjusterOperations;
    }

    function setConstructorArgs(
        AdjusterOperationsArgs calldata args_
    ) external {
        args = args_;
    }
}
