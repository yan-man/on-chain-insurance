// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {InsuranceCoverageNFT} from "../contracts/InsuranceCoverageNFT.sol";

/// @title Script to deploy InsuranceCoverageNFT contract
contract DeployInsuranceCoverageNFT is Script {
    struct InsuranceCoverageNFTArgs {
        address managerContract;
    }
    InsuranceCoverageNFTArgs public args;
    InsuranceCoverageNFT public insuranceCoverageNFT;

    function run() external returns (InsuranceCoverageNFT) {
        vm.startBroadcast();
        insuranceCoverageNFT = new InsuranceCoverageNFT(args.managerContract);
        vm.stopBroadcast();
        return insuranceCoverageNFT;
    }

    function setConstructorArgs(
        InsuranceCoverageNFTArgs calldata args_
    ) external {
        args = args_;
    }
}
