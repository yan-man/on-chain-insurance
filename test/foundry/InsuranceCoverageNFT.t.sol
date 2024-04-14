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

    function test_deploymentParams_success() external view {
        assertTrue(
            insuranceCoverageNFT.hasRole(
                insuranceCoverageNFT.MANAGER_CONTRACT(),
                args.managerContract
            )
        );
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
        coverageDuration_ = bound(
            coverageDuration_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );

        vm.startPrank(args.managerContract);
        uint256 _expectedId = 0;
        bool _expectedIsActive = true;
        vm.expectEmit(true, true, true, false);
        emit IERC721.Transfer(address(0), to_, _expectedId);
        vm.expectEmit(true, true, false, true);
        emit InsuranceCoverageNFT.PolicyCreated(
            _expectedId,
            to_,
            premium_,
            block.timestamp,
            block.timestamp + coverageDuration_,
            _expectedIsActive
        );
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            coverageDuration_
        );
        vm.stopPrank();
        (
            uint256 _id,
            uint256 _premium,
            uint256 _startTime,
            uint256 _endTime,
            bool _isActive
        ) = insuranceCoverageNFT.policyDetails(_tokenId);
        assertEq(_id, _tokenId);
        assertEq(_premium, premium_);
        assertEq(_startTime, block.timestamp);
        assertEq(_endTime, block.timestamp + coverageDuration_);
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
        coverageDuration_ = bound(
            coverageDuration_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );

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
        coverageDuration_ = bound(
            coverageDuration_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );

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
        vm.assume(
            coverageDuration_ == 0 ||
                coverageDuration_ > insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );

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
        coverageDuration_ = bound(
            coverageDuration_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );

        vm.startPrank(args.managerContract);
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            coverageDuration_
        );
        vm.stopPrank();

        (, uint256 _premium0, uint256 _startTime0, , ) = insuranceCoverageNFT
            .policyDetails(_tokenId);

        skip(3600); // 1 hour

        vm.startPrank(to_);
        vm.expectEmit(true, true, true, false);
        emit IERC721.Transfer(to_, address(0), _tokenId);
        vm.expectEmit(true, false, false, false);
        emit InsuranceCoverageNFT.PolicyInactive(_tokenId);
        insuranceCoverageNFT.burn(_tokenId);
        vm.stopPrank();

        (
            ,
            uint256 _premium1,
            uint256 _startTime1,
            uint256 _endTime1,
            bool _isActive1
        ) = insuranceCoverageNFT.policyDetails(_tokenId);
        // unchanged values
        assertEq(_premium0, _premium1);
        assertEq(_startTime0, _startTime1);
        // updated values
        assertEq(_endTime1, block.timestamp);
        assertFalse(_isActive1);
    }

    function test_burn_fail_invalidOwner(
        address to_,
        uint256 premium_,
        uint256 coverageDuration_,
        address nonOwner_
    ) public {
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(
            to_ != address(0) && to_.code.length == 0 && to_ != nonOwner_
        );
        vm.assume(premium_ > 0);
        coverageDuration_ = bound(
            coverageDuration_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );

        vm.startPrank(args.managerContract);
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            coverageDuration_
        );
        vm.stopPrank();

        vm.startPrank(nonOwner_);
        vm.expectRevert(
            InsuranceCoverageNFT.InsuranceCoverageNFT_NotOwner.selector
        );
        insuranceCoverageNFT.burn(_tokenId);
        vm.stopPrank();
    }

    function test_extendCoverage_success(
        address to_,
        uint256 premium_,
        uint256 coverageExtension_
    ) public {
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        coverageExtension_ = bound(
            coverageExtension_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION() - 1
        );

        uint256 _coverageDuration = insuranceCoverageNFT
            .MAX_COVERAGE_DURATION() - coverageExtension_;

        vm.startPrank(args.managerContract);
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            _coverageDuration
        );
        (
            ,
            uint256 _premium0,
            uint256 _startTime0,
            uint256 _endTime0,
            bool _isActive0
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        vm.expectEmit(true, true, false, true);
        emit InsuranceCoverageNFT.PolicyExtended(
            _tokenId,
            _premium0,
            _startTime0,
            _endTime0 + coverageExtension_,
            _isActive0
        );
        insuranceCoverageNFT.extendCoverage(_tokenId, coverageExtension_);
        vm.stopPrank();
        (
            ,
            uint256 _premium1,
            uint256 _startTime1,
            uint256 _endTime1,
            bool _isActive1
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        assertEq(_premium1, _premium0);
        assertEq(_startTime1, _startTime0);
        assertEq(_endTime1, _endTime0 + coverageExtension_);
        assertEq(_isActive1, _isActive0);
    }

    function test_extendCoverage_fail_invalidRole(
        address nonManager_,
        address to_,
        uint256 premium_,
        uint256 coverageExtension_
    ) public {
        vm.assume(nonManager_ != args.managerContract);
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        coverageExtension_ = bound(
            coverageExtension_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION() - 1
        );

        uint256 _coverageDuration = insuranceCoverageNFT
            .MAX_COVERAGE_DURATION() - coverageExtension_;

        vm.startPrank(args.managerContract);
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            _coverageDuration
        );
        vm.stopPrank();

        (
            ,
            uint256 _premium0,
            uint256 _startTime0,
            uint256 _endTime0,
            bool _isActive0
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        vm.startPrank(nonManager_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonManager_,
                insuranceCoverageNFT.MANAGER_CONTRACT()
            )
        );
        insuranceCoverageNFT.extendCoverage(_tokenId, coverageExtension_);
        vm.stopPrank();
        (
            ,
            uint256 _premium1,
            uint256 _startTime1,
            uint256 _endTime1,
            bool _isActive1
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        assertEq(_premium1, _premium0);
        assertEq(_startTime1, _startTime0);
        assertEq(_endTime1, _endTime0);
        assertEq(_isActive1, _isActive0);
    }

    function test_extendCoverage_fail_inactivePolicyAfterBurn(
        address nonManager_,
        address to_,
        uint256 premium_,
        uint256 coverageExtension_
    ) public {
        vm.assume(nonManager_ != args.managerContract);
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        coverageExtension_ = bound(
            coverageExtension_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION() - 1
        );

        uint256 _coverageDuration = insuranceCoverageNFT
            .MAX_COVERAGE_DURATION() - coverageExtension_;

        vm.startPrank(args.managerContract);
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            _coverageDuration
        );
        vm.stopPrank();

        (, uint256 _premium0, uint256 _startTime0, , ) = insuranceCoverageNFT
            .policyDetails(_tokenId);

        vm.startPrank(to_);
        insuranceCoverageNFT.burn(_tokenId);
        vm.stopPrank();

        vm.startPrank(args.managerContract);
        vm.expectRevert(
            InsuranceCoverageNFT.InsuranceCoverageNFT_InactivePolicy.selector
        );
        insuranceCoverageNFT.extendCoverage(_tokenId, coverageExtension_);
        vm.stopPrank();
        (
            ,
            uint256 _premium1,
            uint256 _startTime1,
            uint256 _endTime1,
            bool _isActive1
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        assertEq(_premium1, _premium0);
        assertEq(_startTime1, _startTime0);
        // values change after burn
        assertEq(_endTime1, block.timestamp);
        assertEq(_isActive1, false);
    }

    function test_extendCoverage_fail_inactivePolicyAfterExpired(
        address nonManager_,
        address to_,
        uint256 premium_,
        uint256 coverageExtension_
    ) public {
        vm.assume(nonManager_ != args.managerContract);
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        coverageExtension_ = bound(
            coverageExtension_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION() - 1
        );

        uint256 _coverageDuration = insuranceCoverageNFT
            .MAX_COVERAGE_DURATION() - coverageExtension_;

        vm.startPrank(args.managerContract);
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            _coverageDuration
        );
        vm.stopPrank();

        // after coverage duration, so that policy is expired
        skip(_coverageDuration + 1);

        (
            ,
            uint256 _premium0,
            uint256 _startTime0,
            uint256 _endTime0,
            bool _isActive0
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        vm.startPrank(args.managerContract);
        vm.expectRevert(
            InsuranceCoverageNFT.InsuranceCoverageNFT_InactivePolicy.selector
        );
        insuranceCoverageNFT.extendCoverage(_tokenId, coverageExtension_);
        vm.stopPrank();
        (
            ,
            uint256 _premium1,
            uint256 _startTime1,
            uint256 _endTime1,
            bool _isActive1
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        assertEq(_premium1, _premium0);
        assertEq(_startTime1, _startTime0);
        assertEq(_endTime1, _endTime0);
        assertEq(_isActive1, _isActive0);
    }

    function test_extendCoverage_fail_ZeroCoverageDuration(
        address to_,
        uint256 premium_,
        uint256 coverageDuration_
    ) public {
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        coverageDuration_ = bound(
            coverageDuration_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );

        uint _coverageExtension = 0;

        vm.startPrank(args.managerContract);
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            coverageDuration_
        );
        vm.stopPrank();

        (
            ,
            uint256 _premium0,
            uint256 _startTime0,
            uint256 _endTime0,
            bool _isActive0
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        vm.startPrank(args.managerContract);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsuranceCoverageNFT
                    .InsuranceCoverageNFT_InvalidCoverageDuration
                    .selector,
                _coverageExtension
            )
        );
        insuranceCoverageNFT.extendCoverage(_tokenId, _coverageExtension);
        vm.stopPrank();
        (
            ,
            uint256 _premium1,
            uint256 _startTime1,
            uint256 _endTime1,
            bool _isActive1
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        assertEq(_premium1, _premium0);
        assertEq(_startTime1, _startTime0);
        assertEq(_endTime1, _endTime0);
        assertEq(_isActive1, _isActive0);
    }

    function test_extendCoverage_fail_invalidCoverageDuration(
        address to_,
        uint256 premium_,
        uint256 coverageDuration_
    ) public {
        /// @dev to_ also cannot be a contract address unless it implements onERC721Received
        vm.assume(to_ != address(0) && to_.code.length == 0);
        vm.assume(premium_ > 0);
        coverageDuration_ = bound(
            coverageDuration_,
            1,
            insuranceCoverageNFT.MAX_COVERAGE_DURATION()
        );

        uint256 coverageExtension_ = insuranceCoverageNFT
            .MAX_COVERAGE_DURATION() + coverageDuration_;

        vm.startPrank(args.managerContract);
        uint256 _tokenId = insuranceCoverageNFT.mint(
            to_,
            premium_,
            coverageDuration_
        );
        vm.stopPrank();

        (
            ,
            uint256 _premium0,
            uint256 _startTime0,
            uint256 _endTime0,
            bool _isActive0
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        vm.startPrank(args.managerContract);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsuranceCoverageNFT
                    .InsuranceCoverageNFT_InvalidCoverageDuration
                    .selector,
                coverageExtension_
            )
        );
        insuranceCoverageNFT.extendCoverage(_tokenId, coverageExtension_);
        vm.stopPrank();
        (
            ,
            uint256 _premium1,
            uint256 _startTime1,
            uint256 _endTime1,
            bool _isActive1
        ) = insuranceCoverageNFT.policyDetails(_tokenId);

        assertEq(_premium1, _premium0);
        assertEq(_startTime1, _startTime0);
        assertEq(_endTime1, _endTime0);
        assertEq(_isActive1, _isActive0);
    }
}
