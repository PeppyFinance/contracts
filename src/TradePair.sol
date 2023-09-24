// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "src/interfaces/IPriceFeed.sol";
import "src/interfaces/ILiquidityPool.sol";
import "src/interfaces/ITradePair.sol";

contract TradePair is ITradePair {
    using SafeERC20 for IERC20;

    uint256 private _nextId;

    mapping(uint256 => Position) positions;

    IERC20 public collateralToken;
    int256 public borrowRate = 0.00001 * 1e6; // 0.001% per hour
    uint256 public liquidatorReward = 1 * 1e8; // Same decimals as collateral

    IPriceFeed public priceFeed;
    ILiquidityPool public liquidityPool;

    uint256 public longOpenInterest;
    uint256 public shortOpenInterest;

    int256 public borrowFeeIntegral;
    int256 public fundingFeeIntegral;
    uint256 public lastUpdateTimestamp;

    int256 public maxFundingRate; // 1e18
    int256 public maxRelativeSkew; // 1e18

    constructor(address _collateralToken, IPriceFeed _priceFeed) {
        collateralToken = IERC20(_collateralToken);
        priceFeed = _priceFeed;
    }

    function openPosition(uint256 collateral, uint256 leverage, int8 direction, bytes[] memory _priceUpdateData) external payable {
        updateFeeIntegrals();
        int256 entryPrice = _getPrice(_priceUpdateData);
        uint256 id = ++_nextId;
        positions[id] = Position(
            collateral,
            entryPrice,
            block.timestamp,
            leverage,
            borrowFeeIntegral,
            fundingFeeIntegral,
            msg.sender,
            direction
        );
        if (direction == 1) {
            longOpenInterest += collateral * leverage / 1e6;
        } else {
            shortOpenInterest += collateral * leverage / 1e6;
        }
        collateralToken.safeTransferFrom(msg.sender, address(this), collateral);

        emit PositionOpened(msg.sender, id, entryPrice, leverage, direction);
    }

    function closePosition(uint256 id, bytes[] memory _priceUpdateData) external payable {
        updateFeeIntegrals();
        Position storage position = positions[id];
        require(position.owner == msg.sender, "Only the owner can close the position");
        uint256 value = _getValue(id, _getPrice(_priceUpdateData));
        if (position.direction == 1) {
            longOpenInterest -= position.collateral * position.leverage / 1e6;
        } else {
            shortOpenInterest -= position.collateral * position.leverage / 1e6;
        }
        delete positions[id];
        if (value > 0) {
            // Position is not underwater.
            if (value > position.collateral) {
                // Position is profitable.
                liquidityPool.requestPayout(value - position.collateral);
            } else {
                // Position is not profitable. Transfer PnL and fee to LP.
                collateralToken.safeTransfer(address(liquidityPool), position.collateral - value);
            }
            // In all cases, owner receives the (leftover) value.
            collateralToken.safeTransfer(msg.sender, value);
        } else {
            // Position is underwater. All collateral goes to LP
            collateralToken.safeTransfer(address(liquidityPool), position.collateral);
        }

        emit PositionClosed(position.owner, id, value);
    }

    function liquidatePosition(uint256 id, bytes[] memory _priceUpdateData) external payable {
        updateFeeIntegrals();
        Position storage position = positions[id];
        require(position.owner != address(0), "Position does not exist");
        require(_getValue(id, _getPrice(_priceUpdateData)) <= 0, "Position is not liquidatable");
        if (position.direction == 1) {
            longOpenInterest -= position.collateral * position.leverage / 1e6;
        } else {
            shortOpenInterest -= position.collateral * position.leverage / 1e6;
        }
        delete positions[id];
        collateralToken.safeTransfer(msg.sender, liquidatorReward);
        collateralToken.safeTransfer(address(liquidityPool), position.collateral - liquidatorReward);

        emit PositionLiquidated(position.owner, id);
    }

    function getPositionDetails(uint256 id, int256 price) external view returns (PositionDetails memory) {
        Position storage position = positions[id];
        require(position.owner != address(0), "Position does not exist");
        return PositionDetails(
            id,
            position.collateral,
            position.entryPrice,
            position.entryTimestamp,
            position.leverage,
            (borrowFeeIntegral - position.borrowFeeIntegral) * int256(position.collateral) * int256(position.leverage)
                / 1e6 / 1 hours,
            (fundingFeeIntegral - position.fundingFeeIntegral) * int256(position.collateral) * int256(position.leverage)
                / 1e6 / 1 hours,
            position.owner,
            position.direction,
            _getValue(id, price)
        );
    }

    function _getValue(uint256 id, int256 price) internal view returns (uint256) {
        Position storage position = positions[id];
        int256 profit = (price - position.entryPrice) * int256(position.leverage) * int256(position.collateral)
            * position.direction / position.entryPrice / 1e6;
        int256 borrowFee = (borrowFeeIntegral - position.borrowFeeIntegral) * int256(position.collateral)
            * int256(position.leverage) / 1e6 / 1 hours;
        int256 fundingFee = (fundingFeeIntegral - position.fundingFeeIntegral) * int256(position.collateral)
            * int256(position.leverage) / 1e6 / 1 hours;
        int256 value = int256(position.collateral) + profit - borrowFee - fundingFee;
        if (value < 0) {
            return 0;
        }
        return uint256(value);
    }

    function _getPrice(bytes[] memory _priceUpdateData) internal returns (int256) {
        int256 price = priceFeed.getPrice(address(liquidityPool.asset()), _priceUpdateData);
        require(price > 0, "TradePair::_getPrice: Failed to fetch the current price.");
        return price;
    }

    function excessOpenInterest() public view returns (uint256) {
        if (longOpenInterest > shortOpenInterest) {
            return longOpenInterest - shortOpenInterest;
        } else {
            return shortOpenInterest - longOpenInterest;
        }
    }

    function updateFeeIntegrals() public {
        fundingFeeIntegral += _calculateFundingRate() * int256(block.timestamp - lastUpdateTimestamp);
        borrowFeeIntegral += _calculateBorrowRate() * int256(block.timestamp - lastUpdateTimestamp);
        lastUpdateTimestamp = block.timestamp;
    }

    /// @dev Positive funding rate means longs pay shorts
    function _calculateFundingRate() internal view returns (int256) {
        if (longOpenInterest > shortOpenInterest) {
            int256 relativeSkew = int256(longOpenInterest) * 1e18 / int256(shortOpenInterest);
            return maxFundingRate * relativeSkew / maxRelativeSkew;
        }
        if (shortOpenInterest > longOpenInterest) {
            int256 relativeSkew = int256(shortOpenInterest) * 1e18 / int256(longOpenInterest);
            return -maxFundingRate * relativeSkew / maxRelativeSkew;
        }
        return 0;
    }

    function _calculateBorrowRate() internal view returns (int256) {
        uint256 totalAssets = liquidityPool.totalAssets();
        uint256 utilization = excessOpenInterest() * 1e18 / totalAssets;
        return liquidityPool.maxBorrowRate() * int256(utilization) / 1e18;
    }
}
