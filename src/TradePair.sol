// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "src/interfaces/IPriceFeed.sol";
import "src/interfaces/ILiquidityPool.sol";

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

contract TradePair {
    using SafeERC20 for IERC20;

    mapping(uint256 => Position) positions;
    uint256 nextId;
    IERC20 public collateralToken;
    int256 borrowRate = 0.00001 * 1e6; // 0.001% per hour
    uint256 liquidatorReward = 1 * 1e8; // Same decimals as collateral
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

    function openPosition(uint256 collateral, uint256 leverage, int8 direction) external {
        int256 entryPrice = _getPrice();
        positions[++nextId] = Position(
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
    }

    function closePosition(uint256 id) external {
        Position storage position = positions[id];
        require(position.owner == msg.sender, "Only the owner can close the position");
        uint256 value = _getValue(id);
        if (position.direction == 1) {
            longOpenInterest -= position.collateral * position.leverage / 1e6;
        } else {
            shortOpenInterest -= position.collateral * position.leverage / 1e6;
        }
        delete positions[id];
        if (value > 0) {
            // Position is
            if (value > position.collateral) {
                liquidityPool.requestPayout(value - position.collateral);
            } else {
                collateralToken.safeTransfer(address(liquidityPool), position.collateral - value);
            }
            collateralToken.safeTransfer(msg.sender, value);
        } else {
            // Position is underwater. All collateral goes to LP
            collateralToken.safeTransfer(msg.sender, position.collateral - value);
        }
    }

    function liquidatePosition(uint256 id) external {
        Position storage position = positions[id];
        require(position.owner != address(0), "Position does not exist");
        require(_getValue(id) <= 0, "Position is not liquidatable");
        if (position.direction == 1) {
            longOpenInterest -= position.collateral * position.leverage / 1e6;
        } else {
            shortOpenInterest -= position.collateral * position.leverage / 1e6;
        }
        delete positions[id];
        collateralToken.safeTransfer(msg.sender, liquidatorReward);
        collateralToken.safeTransfer(address(liquidityPool), position.collateral - liquidatorReward);
    }

    function _getValue(uint256 id) internal view returns (uint256) {
        Position storage position = positions[id];
        int256 currentPrice = _getPrice();
        int256 profit = (currentPrice - position.entryPrice) * int256(position.leverage) * int256(position.collateral)
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

    function _getPrice() internal view returns (int256) {
        int256 price = priceFeed.getPrice();
        require(price > 0, "TradePair::_getCurrentPrice: Failed to fetch the current price.");
        return price;
    }

    function excessOpenInterest() public view returns (uint256) {
        if (longOpenInterest > shortOpenInterest) {
            return longOpenInterest - shortOpenInterest;
        } else {
            return shortOpenInterest - longOpenInterest;
        }
    }

    function updateFeeIntegrals() external {
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
