// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "src/interfaces/IController.sol";
import "src/interfaces/IPriceFeed.sol";
import "src/interfaces/ILiquidityPool.sol";
import "src/interfaces/ITradePair.sol";

import "forge-std/console2.sol";

contract TradePair is ITradePair {
    using SafeERC20 for IERC20;

    uint256 private _nextId;

    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositionIds;

    // needed for efficient deletion of positions in userPositionIds array
    mapping(address => mapping(uint256 => uint256)) private userPositionIndex;

    uint256 public liquidatorReward = 1 * 1e18; // Same decimals as collateral

    IController public controller;
    IPriceFeed public priceFeed;
    ILiquidityPool public liquidityPool;
    IERC20 public collateralToken;

    int256 public longOpenInterest;
    int256 public shortOpenInterest;

    int256 public longTotalAssets;
    int256 public shortTotalAssets;

    int256 public longCollateral;
    int256 public shortCollateral;

    int256 public borrowFeeIntegral;
    int256 public fundingFeeIntegral;
    uint256 public lastUpdateTimestamp;

    int256 public maxFundingRate; // in BPS (1e6)
    int256 public maxSkew; // in BPS (1e6) (for simplicity reasons)

    int8 constant LONG = 1;
    int8 constant SHORT = -1;
    int256 immutable ASSET_MULTIPLIER;

    uint256 MIN_LEVERAGE = 1e6;
    uint256 MAX_LEVERAGE = 100 * 1e6;

    constructor(
        IController _controller,
        IERC20 _collateralToken,
        IPriceFeed _priceFeed,
        ILiquidityPool _liquidityPool,
        uint8 _assetDecimals
    ) {
        controller = _controller;
        collateralToken = _collateralToken;
        priceFeed = _priceFeed;
        liquidityPool = _liquidityPool;
        ASSET_MULTIPLIER = int256(10 ** _assetDecimals);
        lastUpdateTimestamp = block.timestamp;
        maxSkew = 5 * BPS;
    }

    function openPosition(uint256 collateral, uint256 leverage, int8 direction, bytes[] memory priceUpdateData_)
        external
        payable
    {
        require(leverage >= MIN_LEVERAGE, "TradePair::openPosition: Leverage too low");
        require(leverage <= MAX_LEVERAGE, "TradePair::openPosition: Leverage too high");

        updateFeeIntegrals();
        int256 entryPrice = _getPrice(priceUpdateData_);
        uint256 id = ++_nextId;
        int256 volume = int256(collateral * leverage / 1e6);
        int256 assets = int256(volume) * ASSET_MULTIPLIER / entryPrice;

        positions[id] = Position(
            collateral, volume, assets, block.timestamp, borrowFeeIntegral, fundingFeeIntegral, msg.sender, direction
        );
        userPositionIds[msg.sender].push(id);
        userPositionIndex[msg.sender][id] = userPositionIds[msg.sender].length - 1;

        _updateOpenInterest(volume, direction);
        _updateTotalAssets(int256(assets), direction);
        _updateCollateral(int256(collateral), direction);

        collateralToken.safeTransferFrom(msg.sender, address(this), collateral);

        syncUnrealizedPnL(priceUpdateData_);

        emit PositionOpened(msg.sender, id, entryPrice, collateral, leverage, direction);
    }

    function closePosition(uint256 id, bytes[] memory priceUpdateData_) external payable {
        updateFeeIntegrals();
        Position storage position = positions[id];
        require(position.owner == msg.sender, "TradePair::closePosition: Only the owner can close the position");
        int256 closePrice = _getPrice(priceUpdateData_);
        uint256 value = _getValue(id, closePrice);
        require(value > 0, "Position is liquidatable");

        _updateOpenInterest(-1 * position.entryVolume, position.direction);
        _updateTotalAssets(-1 * int256(position.assets), position.direction);
        _updateCollateral(-1 * int256(position.collateral), position.direction);

        if (value > position.collateral) {
            // Position is profitable.
            // Make sure that tradePair has enough balance:
            uint256 balance = collateralToken.balanceOf(address(this));
            if (balance < value) {
                liquidityPool.requestPayout(value - balance);
            }
        } else {
            // Position is not profitable. Transfer PnL and fee to LP.
            collateralToken.safeTransfer(address(liquidityPool), position.collateral - value);
        }
        // In all cases, owner receives the (leftover) value.
        collateralToken.safeTransfer(msg.sender, value);

        _dropPosition(id, position.owner);
        syncUnrealizedPnL(priceUpdateData_);
        emit PositionClosed(position.owner, id, value);
    }

    function liquidatePosition(uint256 id, bytes[] memory priceUpdateData_) external payable {
        updateFeeIntegrals();
        Position storage position = positions[id];
        require(position.owner != address(0), "Position does not exist");
        int256 closePrice = _getPrice(priceUpdateData_);

        require(_getValue(id, closePrice) <= 0, "Position is not liquidatable");

        _updateOpenInterest(-1 * position.entryVolume, position.direction);
        _updateTotalAssets(-1 * int256(position.assets), position.direction);
        _updateCollateral(-1 * int256(position.collateral), position.direction);

        collateralToken.safeTransfer(msg.sender, liquidatorReward);
        collateralToken.safeTransfer(address(liquidityPool), position.collateral - liquidatorReward);

        _dropPosition(id, position.owner);
        syncUnrealizedPnL(priceUpdateData_);
        emit PositionLiquidated(position.owner, id);
    }

    function syncUnrealizedPnL(bytes[] memory priceUpdateData_) public {
        int256 _unrealizedPnL = unrealizedPnL(priceUpdateData_);
        int256 balance = int256(collateralToken.balanceOf(address(this)));

        // Target Balance is minimum the total collateral and maximum the total collateral + unrealizedPnL
        int256 targetBalance = totalCollateral();
        if (_unrealizedPnL > 0) {
            targetBalance += _unrealizedPnL;
        }

        int256 missingAmount = targetBalance - balance;

        if (missingAmount > 0) {
            liquidityPool.requestPayout(uint256(missingAmount));
        } else {
            collateralToken.safeTransfer(address(liquidityPool), uint256(-1 * missingAmount));
        }
    }

    function getPositionDetails(uint256 id, int256 price) public view returns (PositionDetails memory) {
        Position storage position = positions[id];
        require(position.owner != address(0), "Position does not exist");
        return PositionDetails(
            id,
            position.collateral,
            position.entryVolume,
            position.assets,
            position.entryTimestamp,
            (borrowFeeIntegral - position.borrowFeeIntegral) * position.entryVolume / 1e6 / 1 hours,
            (fundingFeeIntegral - position.fundingFeeIntegral) * position.entryVolume / 1e6 / 1 hours,
            position.owner,
            position.direction,
            _getValue(id, price)
        );
    }

    function totalCollateral() public view returns (int256) {
        return longCollateral + shortCollateral;
    }

    function getUserPositionsCount(address user) external view returns (uint256) {
        return userPositionIds[user].length;
    }

    function getUserPositionByIndex(address user, uint256 index, int256 price)
        external
        view
        returns (PositionDetails memory)
    {
        return getPositionDetails(userPositionIds[user][index], price);
    }

    function unrealizedPnL(bytes[] memory priceUpdateData_) public returns (int256) {
        int256 price = _getPrice(priceUpdateData_);

        int256 longTotalAssetsValue = longTotalAssets * price / ASSET_MULTIPLIER;
        int256 shortTotalAssetsValue = shortTotalAssets * price / ASSET_MULTIPLIER;

        return longTotalAssetsValue - longOpenInterest + shortOpenInterest - shortTotalAssetsValue;
    }

    function setMaxFundingRate(int256 maxFundingRate_) external {
        maxFundingRate = maxFundingRate_;

        emit MaxFundingRateSet(maxFundingRate_);
    }

    function setMaxSkew(int256 maxSkew_) external {
        maxSkew = maxSkew_;

        emit MaxSkewSet(maxSkew_);
    }

    function _updateCollateral(int256 addedCollateral, int8 direction) internal {
        if (direction == LONG) {
            longCollateral += addedCollateral;
        } else if (direction == SHORT) {
            shortCollateral += addedCollateral;
        } else {
            revert("TradePair::_updateCollateral: Invalid direction");
        }
    }

    function _updateOpenInterest(int256 addedVolume, int8 direction) internal {
        if (direction == LONG) {
            longOpenInterest += addedVolume;
        } else if (direction == SHORT) {
            shortOpenInterest += addedVolume;
        } else {
            revert("TradePair::_updateOpenInterest: Invalid direction");
        }
    }

    function _updateTotalAssets(int256 addedAssets, int8 direction) internal {
        if (direction == LONG) {
            longTotalAssets += addedAssets;
        } else if (direction == SHORT) {
            shortTotalAssets += addedAssets;
        } else {
            revert("TradePair::_updateTotalAssets: Invalid direction");
        }
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

        int256 assetValue = position.assets * price / ASSET_MULTIPLIER;
        int256 profit = (assetValue - position.entryVolume) * position.direction;
        int256 borrowFee = (borrowFeeIntegral - position.borrowFeeIntegral) * position.entryVolume / 1e6 / 1 hours;
        int256 fundingFee = (fundingFeeIntegral - position.fundingFeeIntegral) * position.entryVolume / 1e6 / 1 hours;
        int256 value = int256(position.collateral) + profit - borrowFee - fundingFee;

        // A position can not have a negative value, as "after" liquidation nothing is left.
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

    function totalOpenInterest() public view returns (int256) {
        return int256(longOpenInterest) - int256(shortOpenInterest);
    }

    function excessOpenInterest() public view returns (int256) {
        if (longOpenInterest > shortOpenInterest) {
            return longOpenInterest - shortOpenInterest;
        } else {
            return shortOpenInterest - longOpenInterest;
        }
    }

    function unrealizedBorrowFeeIntegral() public view returns (int256) {
        return getBorrowRate() * int256(block.timestamp - lastUpdateTimestamp) / 1 hours;
    }

    function unrealizedFundingFeeIntegral() public view returns (int256) {
        return getFundingRate() * int256(block.timestamp - lastUpdateTimestamp) / 1 hours;
    }

    function updateFeeIntegrals() public {
        fundingFeeIntegral += unrealizedFundingFeeIntegral();
        borrowFeeIntegral += unrealizedBorrowFeeIntegral();
        lastUpdateTimestamp = block.timestamp;
    }

    /// @dev Positive funding rate means longs pay shorts
    function getFundingRate() public view returns (int256) {
        if (longOpenInterest > shortOpenInterest) {
            if (shortOpenInterest == 0) {
                return maxFundingRate;
            }
            int256 relativeSkew = int256(longOpenInterest) * BPS / int256(shortOpenInterest);
            return maxFundingRate * relativeSkew / maxSkew;
        }
        if (shortOpenInterest > longOpenInterest) {
            if (longOpenInterest == 0) {
                return -1 * maxFundingRate;
            }
            int256 relativeSkew = int256(shortOpenInterest) * BPS / int256(longOpenInterest);
            return -maxFundingRate * relativeSkew / maxSkew;
        }
        return 0;
    }

    function getBorrowRate() public view returns (int256) {
        return liquidityPool.getBorrowRate(excessOpenInterest());
    }
}
