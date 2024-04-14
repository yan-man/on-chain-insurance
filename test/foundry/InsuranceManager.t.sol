// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
// import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

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
    DeployInsuranceManager.InsuranceManagerArgs public args;
    DeployInsuranceManager public deployInsuranceManager;
    InsuranceCoverageNFT public insuranceCoverageNFT;
    AdjusterOperations public adjusterOperations;
    InsuranceManager public insuranceManager;
    SampleERC20 public sampleERC20;

    function setUp() external {
        address _masterAdmin = vm.addr(getCounterAndIncrement());

        DeployAdjusterOperations deployAdjusterOperations = new DeployAdjusterOperations();
        deployAdjusterOperations.setConstructorArgs(
            DeployAdjusterOperations.AdjusterOperationsArgs({
                masterAdmin: _masterAdmin
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
    }

    function test_deploymentParams_success() external view {
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
}
