// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IPriceFeed {
    function setPriceFeed(address _token, bytes32 _priceId) external;
    function getPrice(address _token, bytes[] memory _priceUpdateData) external payable returns (uint256);
}
