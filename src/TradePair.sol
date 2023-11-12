// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "src/interfaces/IPriceFeed.sol";
import "src/interfaces/ILiquidityPool.sol";
import "src/interfaces/ITradePair.sol";

contract TradePair is ITradePair {
    using SafeERC20 for IERC20Metadata;

    uint256 private _nextId;

    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositionIds;

    // needed for efficient deletion of positions in userPositionIds array
    mapping(address => mapping(uint256 => uint256)) private userPositionIndex;

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

    constructor(IPriceFeed _priceFeed) {
        priceFeed = _priceFeed;
    }

    function setLiquidityPool(ILiquidityPool liquidityPool_) external {
        liquidityPool = liquidityPool_;
    }

    function openPosition(
        uint256 collateral,
        string calldata index,
        uint256 leverage,
        int8 direction,
        bytes[] memory _priceUpdateData
    ) external payable {
        updateFeeIntegrals();

        int256 entryPrice = _getPrice(index, _priceUpdateData);
        uint256 id = ++_nextId;

        positions[id] = Position(
            collateral,
            index,
            entryPrice,
            block.timestamp,
            leverage,
            borrowFeeIntegral,
            fundingFeeIntegral,
            msg.sender,
            direction
        );
        userPositionIds[msg.sender].push(id);
        userPositionIndex[msg.sender][id] = userPositionIds[msg.sender].length - 1;

        if (direction == 1) {
            longOpenInterest += collateral * leverage / 1e6;
        } else {
            shortOpenInterest += collateral * leverage / 1e6;
        }

        liquidityPool.asset().safeTransferFrom(msg.sender, address(this), collateral);

        emit PositionOpened(msg.sender, id, index, entryPrice, collateral, leverage, direction);
    }

    function closePosition(uint256 id, bytes[] memory _priceUpdateData) external payable {
        updateFeeIntegrals();
        Position storage position = positions[id];
        require(position.owner == msg.sender, "Only the owner can close the position");
        uint256 value = _getValue(id, _getPrice(position.index, _priceUpdateData));
        if (position.direction == 1) {
            longOpenInterest -= position.collateral * position.leverage / 1e6;
        } else {
            shortOpenInterest -= position.collateral * position.leverage / 1e6;
        }

        _dropPosition(id, position.owner);

        if (value > 0) {
            // Position is not underwater.
            if (value > position.collateral) {
                // Position is profitable.
                liquidityPool.requestPayout(value - position.collateral);
            } else {
                // Position is not profitable. Transfer PnL and fee to LP.
                liquidityPool.asset().safeTransfer(address(liquidityPool), position.collateral - value);
            }
            // In all cases, owner receives the (leftover) value.
            liquidityPool.asset().safeTransfer(msg.sender, value);
        } else {
            // Position is underwater. All collateral goes to LP
            liquidityPool.asset().safeTransfer(address(liquidityPool), position.collateral);
        }

        emit PositionClosed(position.owner, id, position.index, value);
    }

    function liquidatePosition(uint256 id, bytes[] memory _priceUpdateData) external payable {
        updateFeeIntegrals();
        Position storage position = positions[id];
        require(position.owner != address(0), "Position does not exist");
        require(_getValue(id, _getPrice(position.index, _priceUpdateData)) <= 0, "Position is not liquidatable");
        if (position.direction == 1) {
            longOpenInterest -= position.collateral * position.leverage / 1e6;
        } else {
            shortOpenInterest -= position.collateral * position.leverage / 1e6;
        }

        _dropPosition(id, position.owner);

        liquidityPool.asset().safeTransfer(msg.sender, liquidatorReward);
        liquidityPool.asset().safeTransfer(address(liquidityPool), position.collateral - liquidatorReward);

        emit PositionLiquidated(position.owner, id);
    }

    function getPositionDetails(uint256 id, int256 price) public view returns (PositionDetails memory) {
        Position storage position = positions[id];
        require(position.owner != address(0), "Position does not exist");
        return PositionDetails(
            id,
            position.index,
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

    function getUserPositionsCount(address user) external view returns (uint256) {
        return userPositionIds[user].length;
    }

    function getUserPositionByIndex(address user, uint256 index, int256 price) external view returns (PositionDetails memory) {
        return getPositionDetails(userPositionIds[user][index], price);
    }

    function _dropPosition(uint256 id, address owner) internal {
        uint256 indexToDelete = userPositionIndex[owner][id];
        uint256 lastIndex = userPositionIds[owner].length - 1;
        uint256 lastId = userPositionIds[owner][lastIndex];

        // override item to be removed with last item and remove last item
        userPositionIds[owner][indexToDelete] = lastId;
        userPositionIndex[owner][lastId] = indexToDelete;
        userPositionIds[owner].pop();

        delete userPositionIndex[owner][id];
        delete positions[id];
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

    function _getPrice(string memory index, bytes[] memory _priceUpdateData) internal returns (int256) {
        int256 price = priceFeed.getPrice(index, _priceUpdateData);
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
            if (shortOpenInterest == 0) {
                return maxFundingRate;
            }
            int256 relativeSkew = int256(longOpenInterest) * 1e18 / int256(shortOpenInterest);
            return maxFundingRate * relativeSkew / maxRelativeSkew;
        }
        if (shortOpenInterest > longOpenInterest) {
            if (longOpenInterest == 0) {
                return maxFundingRate;
            }
            int256 relativeSkew = int256(shortOpenInterest) * 1e18 / int256(longOpenInterest);
            return -maxFundingRate * relativeSkew / maxRelativeSkew;
        }
        return 0;
    }

    function _calculateBorrowRate() internal view returns (int256) {
        uint256 totalAssets = liquidityPool.totalAssets();
        // TODO: missing check for totalAssets != 0 or rather sufficient
        // for opening a position. Should not be in this view function,
        // but this is where it fails.
        uint256 utilization = excessOpenInterest() * 1e18 / totalAssets;
        return liquidityPool.maxBorrowRate() * int256(utilization) / 1e18;
    }
}
