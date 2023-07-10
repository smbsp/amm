// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract ERC777Token is ERC777 {
    constructor(string memory name, string memory symbol, address[] memory defaultOperators)
        ERC777(name, symbol, defaultOperators)
    {
        // Mint initial supply to the contract deployer
        uint256 initialSupply = 1000000 * 10 ** uint256(decimals());
        _mint(msg.sender, initialSupply, "", "");
    }
}
