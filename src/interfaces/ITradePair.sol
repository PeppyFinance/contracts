// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/IERC20.sol";

struct Position {
    uint256 collateral;
    int256 entryVolume;
    int256 assets;
    uint256 entryTimestamp;
    int256 borrowFeeIntegral;
    int256 fundingFeeIntegral;
    address owner;
    int8 direction; // 1 for long, -1 for short
}

interface ITradePair {
    struct PositionDetails {
        uint256 id;
        uint256 collateral;
        int256 entryVolume;
        int256 assets;
        uint256 entryTimestamp;
        int256 borrowFeeAmount;
        int256 fundingFeeAmount;
        address owner;
        int8 direction; // 1 for long, -1 for short
        uint256 value;
    }

    event PositionOpened(
        address indexed owner, uint256 id, int256 entryPrice, uint256 collateral, int256 volume, int8 direction
    );
    event PositionClosed(address indexed owner, uint256 id, uint256 value);
    event PositionLiquidated(address indexed owner, uint256 id);
    event MaxFundingRateSet(int256 maxFundingRate);
    event MaxSkewSet(int256 maxSkew);
    event OpenFeeSet(int256 openFee);
    event CloseFeeSet(int256 closeFee);
    event CloseFeePaid(uint256 amount);

    function openPosition(uint256 collateral, uint256 leverage, int8 direction, bytes[] memory _priceUpdateData)
        external
        payable;
    function closePosition(uint256 id, bytes[] memory _priceUpdateData) external payable;
    function liquidatePosition(uint256 id, bytes[] memory _priceUpdateData) external payable;
    function getPositionDetails(uint256 id, int256 price) external view returns (PositionDetails memory);
    function excessOpenInterest() external view returns (int256);
    function updateFeeIntegrals() external;
    function getBorrowRate() external view returns (int256);
    function getFundingRate() external view returns (int256);
    function maxFundingRate() external view returns (int256);
    function maxSkew() external view returns (int256);
    function setMaxFundingRate(int256 rate) external;
    function setMaxSkew(int256 maxSkew) external;
    function setOpenFee(int256 fee) external;
    function setCloseFee(int256 fee) external;
    function unrealizedBorrowFeeIntegral() external view returns (int256);
    function unrealizedFundingFeeIntegral() external view returns (int256);
    function totalBorrowFeeIntegral() external view returns (int256);
    function totalFundingFeeIntegral() external view returns (int256);
    function collateralToken() external view returns (IERC20);
}
