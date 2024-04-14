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

        address _managerContract = vm.addr(getCounterAndIncrement());
        args = DeployInsuranceCoverageNFT.InsuranceCoverageNFTArgs({
            managerContract: _managerContract
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

    function test_mint_success(
        address to_,
        uint256 premium_,
        uint256 coverageDuration_
    ) public {
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        vm.assume(coverageDuration_ > 0 && coverageDuration_ <= 365 days);

        vm.startPrank(args.managerContract);
        uint256 _expectedId = 0;
        bool _expectedIsActive = true;
        vm.expectEmit(true, true, true, false);
        emit IERC721.Transfer(address(0), to_, _expectedId);
        vm.expectEmit(true, true, true, true);
        emit InsuranceCoverageNFT.PolicyCreated(
            _expectedId,
            to_,
            premium_,
            block.timestamp,
            block.timestamp + coverageDuration_,
            _expectedIsActive
        );
        insuranceCoverageNFT.mint(to_, premium_, coverageDuration_);
        vm.stopPrank();

        uint256 _tokenId = insuranceCoverageNFT.tokenId() - 1;
        (
            uint256 _id,
            uint256 _premium,
            uint256 _startDate,
            uint256 _endDate,
            bool _isActive
        ) = insuranceCoverageNFT.policyDetails(_tokenId);
        assertEq(_id, _tokenId);
        assertEq(_premium, _premium);
        assertEq(_startDate, block.timestamp);
        assertEq(_endDate, block.timestamp + coverageDuration_);
        assertTrue(_isActive);

        assertEq(insuranceCoverageNFT.ownerOf(_tokenId), to_);
        assertEq(insuranceCoverageNFT.balanceOf(to_), 1);
        assertEq(insuranceCoverageNFT.totalSupply(), 1);
    }

    function test_mint_fail_invalidRole(
        address nonManager_,
        address to_,
        uint256 premium_,
        uint256 coverageDuration_
    ) public {
        vm.assume(nonManager_ != args.managerContract);
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        vm.assume(coverageDuration_ > 0 && coverageDuration_ <= 365 days);

        vm.startPrank(nonManager_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonManager_,
                insuranceCoverageNFT.MANAGER_CONTRACT()
            )
        );
        insuranceCoverageNFT.mint(to_, premium_, coverageDuration_);
        vm.stopPrank();
        assertEq(insuranceCoverageNFT.tokenId(), 0);
    }

    function test_mint_fail_invalidPremium(
        address to_,
        uint256 coverageDuration_
    ) public {
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(coverageDuration_ > 0 && coverageDuration_ <= 365 days);

        uint256 _premium = 0;
        vm.startPrank(args.managerContract);
        vm.expectRevert(
            InsuranceCoverageNFT.InsuranceCoverageNFT_InvalidPremium.selector
        );
        insuranceCoverageNFT.mint(to_, _premium, coverageDuration_);
        vm.stopPrank();
        assertEq(insuranceCoverageNFT.tokenId(), 0);
    }

    function test_mint_fail_invalidCoverageDuration(
        address to_,
        uint256 premium_,
        uint256 coverageDuration_
    ) public {
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        vm.assume(coverageDuration_ == 0 || coverageDuration_ > 365 days);

        vm.startPrank(args.managerContract);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsuranceCoverageNFT
                    .InsuranceCoverageNFT_InvalidCoverageDuration
                    .selector,
                coverageDuration_
            )
        );
        insuranceCoverageNFT.mint(to_, premium_, coverageDuration_);
        vm.stopPrank();
        assertEq(insuranceCoverageNFT.tokenId(), 0);
    }

    function test_burn_success(
        address to_,
        uint256 premium_,
        uint256 coverageDuration_
    ) public {
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        vm.assume(coverageDuration_ > 0 && coverageDuration_ <= 365 days);

        vm.startPrank(args.managerContract);
        insuranceCoverageNFT.mint(to_, premium_, coverageDuration_);
        vm.stopPrank();

        uint256 _tokenId = insuranceCoverageNFT.tokenId() - 1;

        vm.startPrank(to_);
        vm.expectEmit(true, true, true, false);
        emit IERC721.Transfer(to_, address(0), _tokenId);
        vm.expectEmit(true, false, false, false);
        emit InsuranceCoverageNFT.PolicyInactive(_tokenId);
        insuranceCoverageNFT.burn(_tokenId);
        vm.stopPrank();
    }
}
