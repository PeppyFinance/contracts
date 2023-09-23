// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IPriceFeed {
    function getPrice() external view returns (int256);
}
