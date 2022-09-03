// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenB is ERC20 {
    constructor(uint _initialSupply) ERC20("TokenB", "TKB") { 
        _mint(msg.sender, _initialSupply);
    }

    function _mint(uint _amount) public {
        _mint(msg.sender, _amount);
    }
}
