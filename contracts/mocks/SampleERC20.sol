// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SampleERC20 is ERC20 {
    constructor() ERC20("USDCOIN", "$USD") {}

    function mint(address recipient_, uint256 amount) public {
        _mint(recipient_, amount);
    }
}
