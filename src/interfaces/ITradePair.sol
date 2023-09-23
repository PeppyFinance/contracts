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
    function openPosition(uint256 collateral, uint256 leverage, int8 direction) external;
    function closePosition(uint256 id) external;
    function liquidatePosition(uint256 id) external;
    function getPositionDetails(uint256 id) external view returns (PositionDetails memory);
    function excessOpenInterest() external view returns (uint256);
    function updateFeeIntegrals() external;
}
