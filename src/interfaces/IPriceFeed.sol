// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IPriceFeed {
    function setPriceFeed(string calldata _index, bytes32 _priceId) external;
    function getPrice(string calldata _index, bytes[] memory _updateData) external payable returns (int256);
}
