// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "src/interfaces/IPriceFeed.sol";

contract MockPriceFeed is IPriceFeed {
    mapping(address => int256) public prices;

    function getPrice(address _token, bytes[] memory /*_updateData*/ ) external payable returns (int256) {
        return prices[_token];
    }

    function setPriceFeed(address _token, bytes32 _priceId) external {}

    function setPrice(address _token, int256 _price) external {
        prices[_token] = _price;
    }
}
