// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/IERC20.sol";
import "pyth-sdk-solidity/IPyth.sol";

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
        address indexed owner,
        uint256 id,
        int256 entryPrice,
        uint256 collateral,
        int256 volume,
        int256 assets,
        int8 direction,
        int256 borrowFeeIntegral,
        int256 fundingFeeIntegral
    );
    event PositionClosed(
        address indexed owner,
        uint256 id,
        uint256 value,
        int256 closePrice,
        int256 borrowFeeAmount,
        int256 fundingFeeAmount
    );
    event PositionLiquidated(address indexed owner, uint256 id, int256 borrowFeeAmount, int256 fundingFeeAmount);
    event MaxFundingRateSet(int256 maxFundingRate);
    event MaxSkewSet(int256 maxSkew);
    event OpenFeeSet(int256 openFee);
    event CloseFeeSet(int256 closeFee);
    event MaxPriceAgeSet(uint256 maxPriceAge);
    event CloseFeePaid(uint256 amount);
    event TradePairConstructed(
        address collateralToken,
        address pyth,
        uint8 assetDecimals,
        uint8 collateralDecimals,
        bytes32 pythId,
        string name
    );

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
    function setMaxPriceAge(uint256 maxPriceAge) external;
    function unrealizedBorrowFeeIntegral() external view returns (int256);
    function unrealizedFundingFeeIntegral() external view returns (int256);
    function totalBorrowFeeIntegral() external view returns (int256);
    function totalFundingFeeIntegral() external view returns (int256);
    function collateralToken() external view returns (IERC20);
    function getUnrealizedPnL(bytes[] memory priceUpdateData_) external payable returns (int256);
    function pyth() external view returns (IPyth);
}
