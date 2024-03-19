// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/ERC20.sol";

contract PeppyUsdc is ERC20 {
    uint256 maxMintable;
    mapping(address => uint256) public minted;

    constructor(string memory name_, string memory symbol_, uint256 maxMintable_, uint256 initialMint_)
        ERC20(name_, symbol_)
    {
        maxMintable = maxMintable_;
        _mint(msg.sender, initialMint_);
    }

    function mint(uint256 _amount) external {
        require(minted[msg.sender] + _amount <= maxMintable, "PeppyUsdc::mint: max mintable exceeded");
        _mint(msg.sender, _amount);
        minted[msg.sender] += _amount;
    }
}
