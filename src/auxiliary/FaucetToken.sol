// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/ERC20.sol";

contract FaucetToken is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function testFaucetToken() public pure {
        revert("FaucetToken::testFaucetToken: This function is for testing purposes only.");
    }
}
