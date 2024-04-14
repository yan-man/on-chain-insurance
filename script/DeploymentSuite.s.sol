// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AdjusterOperations} from "../contracts/AdjusterOperations.sol";
import {InsuranceManager} from "../contracts/InsuranceManager.sol";
import {InsuranceCoverageNFT} from "../contracts/InsuranceCoverageNFT.sol";
import {YieldManager} from "../contracts/YieldManager.sol";

/// @title Script to deploy AdjusterOperations contract
contract DeployAdjusterOperations is Script {
    AdjusterOperations public adjusterOperations;
    YieldManager public yieldManager;
    InsuranceManager public insuranceManager;
    InsuranceCoverageNFT public insuranceCoverageNFT;

    struct Args {
        address masterAdmin;
        address paymentTokenAddress;
        address poolAddress;
    }
    Args public args;

    function run() external {
        address masterAdmin = vm.envAddress("MASTER_ADMIN");
        address paymentTokenAddress = vm.envAddress("PAYMENT_TOKEN_ADDRESS");
        address poolAddress = vm.envAddress("POOL_ADDRESS");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        adjusterOperations = new AdjusterOperations(masterAdmin);
        insuranceManager = new InsuranceManager(
            address(adjusterOperations),
            paymentTokenAddress,
            poolAddress
        );
        vm.stopBroadcast();
    }
}
