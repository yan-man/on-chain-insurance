// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import {CustomTest} from "../helpers/CustomTest.t.sol";
import {Test, console} from "forge-std/Test.sol";

import {DeployInsuranceCoverageNFT} from "../../script/DeployInsuranceCoverageNFT.s.sol";
import {InsuranceCoverageNFT} from "../../contracts/InsuranceCoverageNFT.sol";

contract InsuranceCoverageNFTTest is Test, CustomTest {
    DeployInsuranceCoverageNFT public deployInsuranceCoverageNFT;
    DeployInsuranceCoverageNFT.InsuranceCoverageNFTArgs public args;
    InsuranceCoverageNFT public insuranceCoverageNFT;

    function setUp() external {
        deployInsuranceCoverageNFT = new DeployInsuranceCoverageNFT();

        address _masterAdmin = vm.addr(getCounterAndIncrement());
        args = DeployInsuranceCoverageNFT.InsuranceCoverageNFTArgs({
            managerContract: _masterAdmin
        });
        deployInsuranceCoverageNFT.setConstructorArgs(args);

        insuranceCoverageNFT = deployInsuranceCoverageNFT.run();
    }

    function test_supportsInterface_success() public view {
        // ERC-721 interface ID
        bytes4 _erc721InterfaceID = type(IERC721).interfaceId;
        assertTrue(insuranceCoverageNFT.supportsInterface(_erc721InterfaceID));

        // ERC-721 Enumerable interface ID
        bytes4 _erc721EnumerableInterfaceID = type(IERC721Enumerable)
            .interfaceId;
        assertTrue(
            insuranceCoverageNFT.supportsInterface(_erc721EnumerableInterfaceID)
        );

        // Access Control interface ID
        bytes4 _accessControlInterfaceID = type(IAccessControl).interfaceId;
        assertTrue(
            insuranceCoverageNFT.supportsInterface(_accessControlInterfaceID)
        );
    }

    function test_supportsInterface_fail(bytes4 interfaceId) public view {
        vm.assume(
            interfaceId != type(IERC721).interfaceId &&
                interfaceId != type(IERC721Enumerable).interfaceId &&
                interfaceId != type(IAccessControl).interfaceId
        );
        assertFalse(insuranceCoverageNFT.supportsInterface(interfaceId));
    }
}
