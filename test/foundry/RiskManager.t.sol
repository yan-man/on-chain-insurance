// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {CustomTest} from "../helpers/CustomTest.t.sol";
import {Test, console} from "forge-std/Test.sol";

import {RiskManager} from "../../contracts/libraries/RiskManager.sol";

contract RiskManagerTest is Test, CustomTest {
    using RiskManager for *;

    function setUp() external {}

    function test_calculatePremium() public {
        uint256 value = 10000;
        uint256 riskFactor = 10;
        uint256 result = RiskManager.calculatePremium(value, riskFactor);
        assertEq(result, 120);
    }

    function test_calculateDuration() public {
        uint256 amount = 10000;
        uint256 premium = 10;
        uint256 result = RiskManager.calculateDuration(amount, premium);
        assertEq(result, amount / premium);
    }
}
