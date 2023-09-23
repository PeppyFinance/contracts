// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "src/interfaces/IPriceFeed.sol";

contract PriceFeed is IPriceFeed {
    int256 price;

    constructor(int256 _price) {
        price = _price;
    }

    function getPrice() external view override returns (int256) {
        return price;
    }
}
