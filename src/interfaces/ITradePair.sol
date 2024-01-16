// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

struct Position {
    uint256 collateral;
    int256 entryPrice;
    uint256 entryTimestamp;
    uint256 leverage; // 1e6 = 1x,
    int256 borrowFeeIntegral;
    int256 fundingFeeIntegral;
    address owner;
    int8 direction; // 1 for long, -1 for short
}

struct PositionDetails {
    uint256 id;
    uint256 collateral;
    int256 entryPrice;
    uint256 entryTimestamp;
    uint256 leverage; // 1e6 = 1x,
    int256 borrowFeeAmount;
    int256 fundingFeeAmount;
    address owner;
    int8 direction; // 1 for long, -1 for short
    uint256 value;
}

interface ITradePair {
    event PositionOpened(
        address indexed owner, uint256 id, int256 entryPrice, uint256 collateral, uint256 leverage, int8 direction
    );
    event PositionClosed(address indexed owner, uint256 id, uint256 value);
    event PositionLiquidated(address indexed owner, uint256 id);

    function openPosition(uint256 collateral, uint256 leverage, int8 direction, bytes[] memory _priceUpdateData)
        external
        payable;
    function closePosition(uint256 id, bytes[] memory _priceUpdateData) external payable;
    function liquidatePosition(uint256 id, bytes[] memory _priceUpdateData) external payable;
    function getUserPositionByIndex(address user, uint256 index, int256 price)
        external
        view
        returns (PositionDetails memory);
    function excessOpenInterest() external view returns (uint256);
    function updateFeeIntegrals() external;
}
