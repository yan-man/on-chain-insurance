// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {console} from "forge-std/Test.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";

contract YieldManager is AccessControlEnumerable {
    bytes32 public constant MANAGER_CONTRACT = keccak256("MANAGER_CONTRACT");

    IPool public pool;
    IERC20 public paymentToken;
    address public aTokenAddress;
    address public managerContract;

    constructor(
        address managerContract_,
        address poolAddress_,
        address paymentTokenAddress_
    ) {
        pool = IPool(poolAddress_);
        _grantRole(MANAGER_CONTRACT, managerContract_);
        managerContract = managerContract_;
        paymentToken = IERC20(paymentTokenAddress_);
        aTokenAddress = getATokenAddress(paymentTokenAddress_);
    }

    // Deposit tokens into Aave to earn interest
    function deposit(uint256 amount_) public onlyRole(MANAGER_CONTRACT) {
        paymentToken.approve(address(pool), amount_);
        pool.deposit(address(paymentToken), amount_, address(this), 0);
    }

    // Withdraw tokens from Aave
    function withdraw(
        uint256 amount_,
        address recipient_
    ) public onlyRole(MANAGER_CONTRACT) returns (uint256) {
        return pool.withdraw(address(paymentToken), amount_, recipient_);
    }

    // Check balance of aTokens on Aave
    function getAvailableBalance() public view returns (uint256) {
        return IERC20(aTokenAddress).balanceOf(address(this));
    }

    function getATokenAddress(
        address paymentToken_
    ) public view returns (address) {
        DataTypes.ReserveData memory collateralData = pool.getReserveData(
            paymentToken_
        );
        console.log("here");
        return collateralData.aTokenAddress;
    }
}
