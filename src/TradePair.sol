// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "src/interfaces/IController.sol";
import "src/interfaces/IPriceFeed.sol";
import "src/interfaces/ILiquidityPool.sol";
import "src/interfaces/ITradePair.sol";
import "pyth-sdk-solidity/IPyth.sol";
import "forge-std/console2.sol";

contract TradePair is ITradePair {
    using SafeERC20 for IERC20;

    uint256 private _nextId;

    mapping(uint256 => Position) public positions;

    uint256 public liquidatorReward = 1 * 1e18; // Same decimals as collateral

    IController public controller;
    ILiquidityPool public liquidityPool;
    IERC20 public collateralToken;
    IPyth public pyth;

    bytes32 public pythId;
    uint256 public priceFeedUpdateFee = 1;

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
    int256 public openFee;
    int256 public closeFee;

    int8 constant LONG = 1;
    int8 constant SHORT = -1;
    int256 immutable ASSET_MULTIPLIER;
    int256 immutable COLLATERAL_MULTIPLIER;
    int256 GLOBAL_MULTIPLIER = 10 ** 30;

    uint256 MIN_LEVERAGE = 1e6;
    uint256 MAX_LEVERAGE = 100 * 1e6;

    constructor(
        IController controller_,
        ILiquidityPool liquidityPool_,
        uint8 assetDecimals_,
        uint8 collateralDecimals_,
        address pyth_,
        bytes32 pythId_
    ) {
        controller = controller_;
        pyth = IPyth(pyth_);
        pythId = pythId_;
        liquidityPool = liquidityPool_;
        collateralToken = liquidityPool.asset();
        ASSET_MULTIPLIER = int256(10 ** assetDecimals_);
        COLLATERAL_MULTIPLIER = int256(10 ** collateralDecimals_);
        lastUpdateTimestamp = block.timestamp;
        maxSkew = 5 * BPS;
    }

    modifier updatePriceFeeds(bytes[] memory priceUpdateData_) {
        pyth.updatePriceFeeds{value: priceFeedUpdateFee}(priceUpdateData_);
        _;
    }

    function openPosition(uint256 collateral, uint256 leverage, int8 direction, bytes[] memory priceUpdateData_)
        external
        payable
        updatePriceFeeds(priceUpdateData_)
    {
        require(leverage >= MIN_LEVERAGE, "TradePair::openPosition: Leverage too low");
        require(leverage <= MAX_LEVERAGE, "TradePair::openPosition: Leverage too high");
        require(direction == LONG || direction == SHORT, "TradePair::openPosition: Invalid direction");

        updateFeeIntegrals();
        int256 entryPrice = _getPrice();
        uint256 id = ++_nextId;
        int256 volume = int256(collateral * leverage / 1e6);
        int256 assets = int256(volume) * ASSET_MULTIPLIER * GLOBAL_MULTIPLIER / entryPrice / COLLATERAL_MULTIPLIER;
        uint256 openFeeAmount = uint256(openFee * volume / 10_000 / BPS);

        positions[id] = Position(
            collateral, volume, assets, block.timestamp, borrowFeeIntegral, fundingFeeIntegral, msg.sender, direction
        );

        _updateOpenInterest(volume, direction);
        _updateTotalAssets(int256(assets), direction);
        _updateCollateral(int256(collateral), direction);

        collateralToken.safeTransferFrom(msg.sender, address(this), collateral + openFeeAmount);
        collateralToken.safeTransfer(address(liquidityPool), openFeeAmount);

        _syncUnrealizedPnL();

        emit PositionOpened({
            owner: msg.sender,
            id: id,
            entryPrice: entryPrice,
            collateral: collateral,
            volume: volume,
            assets: assets,
            direction: direction,
            borrowFeeIntegral: borrowFeeIntegral,
            fundingFeeIntegral: fundingFeeIntegral
        });
    }

    function closePosition(uint256 id, bytes[] memory priceUpdateData_)
        external
        payable
        updatePriceFeeds(priceUpdateData_)
    {
        updateFeeIntegrals();
        Position storage position = positions[id];
        require(position.owner == msg.sender, "TradePair::closePosition: Only the owner can close the position");
        int256 closePrice = _getPrice();
        uint256 value = _getValue(id, closePrice);
        require(value > 0, "TradePair::closePosition: Position is liquidatable and can not be closed");
        uint256 closeFeeAmount = uint256(closeFee) * value / 10_000 / uint256(BPS);
        uint256 valueAfterFee = value - closeFeeAmount;

        _updateOpenInterest(-1 * position.entryVolume, position.direction);
        _updateTotalAssets(-1 * int256(position.assets), position.direction);
        _updateCollateral(-1 * int256(position.collateral), position.direction);

        if (valueAfterFee > position.collateral) {
            // Position is profitable.
            // Make sure that tradePair has enough balance:
            uint256 balance = collateralToken.balanceOf(address(this));
            if (balance < valueAfterFee) {
                liquidityPool.requestPayout(valueAfterFee - balance);
            }
        } else {
            // Position is not profitable. Transfer PnL and fee to LP.
            collateralToken.safeTransfer(address(liquidityPool), position.collateral - valueAfterFee);
        }
        // In all cases, owner receives the (leftover) value.
        collateralToken.safeTransfer(msg.sender, valueAfterFee);

        _syncUnrealizedPnL();
        emit PositionClosed(
            position.owner, id, value, closePrice, _getBorrowFeeAmount(position), _getFundingFeeAmount(position)
        );
        emit CloseFeePaid(closeFeeAmount);

        _deletePosition(id);
    }

    function liquidatePosition(uint256 id, bytes[] memory priceUpdateData_)
        external
        payable
        updatePriceFeeds(priceUpdateData_)
    {
        updateFeeIntegrals();
        Position storage position = positions[id];
        require(position.owner != address(0), "TradePair::liquidatePosition: Position does not exist");
        int256 closePrice = _getPrice();

        require(_getValue(id, closePrice) <= 0, "TradePair::liquidatePosition: Position is not liquidatable");

        _updateOpenInterest(-1 * position.entryVolume, position.direction);
        _updateTotalAssets(-1 * int256(position.assets), position.direction);
        _updateCollateral(-1 * int256(position.collateral), position.direction);

        collateralToken.safeTransfer(msg.sender, liquidatorReward);
        collateralToken.safeTransfer(address(liquidityPool), position.collateral - liquidatorReward);

        _syncUnrealizedPnL();
        emit PositionLiquidated(position.owner, id, _getBorrowFeeAmount(position), _getFundingFeeAmount(position));

        _deletePosition(id);
    }

    function syncUnrealizedPnL(bytes[] memory priceUpdateData_) public payable updatePriceFeeds(priceUpdateData_) {
        _syncUnrealizedPnL();
    }

    function _syncUnrealizedPnL() internal {
        int256 unrealizedPnLNow = _getUnrealizedPnL();
        int256 balance = int256(collateralToken.balanceOf(address(this)));

        // Target Balance is minimum the total collateral and maximum the total collateral + unrealizedPnL
        int256 targetBalance = totalCollateral();
        if (unrealizedPnLNow > 0) {
            targetBalance += unrealizedPnLNow;
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
        require(position.owner != address(0), "TradePair::getPositionDetails: Position does not exist");

        return PositionDetails(
            id,
            position.collateral,
            position.entryVolume,
            position.assets,
            position.entryTimestamp,
            (totalBorrowFeeIntegral() - position.borrowFeeIntegral) * position.entryVolume / 10_000 / BPS,
            (totalFundingFeeIntegral() - position.fundingFeeIntegral) * position.entryVolume / 10_000 / BPS,
            position.owner,
            position.direction,
            _getValue(id, price)
        );
    }

    function totalCollateral() public view returns (int256) {
        return longCollateral + shortCollateral;
    }

    function getUnrealizedPnL(bytes[] memory priceUpdateData_)
        external
        payable
        updatePriceFeeds(priceUpdateData_)
        returns (int256)
    {
        return _getUnrealizedPnL();
    }

    function _getUnrealizedPnL() internal view returns (int256) {
        int256 price = _getPrice();

        int256 longTotalAssetsValue =
            longTotalAssets * price * COLLATERAL_MULTIPLIER / ASSET_MULTIPLIER / GLOBAL_MULTIPLIER;
        int256 shortTotalAssetsValue =
            shortTotalAssets * price * COLLATERAL_MULTIPLIER / ASSET_MULTIPLIER / GLOBAL_MULTIPLIER;

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

    function setOpenFee(int256 openFee_) external {
        openFee = openFee_;

        emit OpenFeeSet(openFee_);
    }

    function setCloseFee(int256 closeFee_) external {
        closeFee = closeFee_;

        emit CloseFeeSet(closeFee_);
    }

    function _updateCollateral(int256 addedCollateral, int8 direction) internal {
        if (direction == LONG) {
            longCollateral += addedCollateral;
        } else if (direction == SHORT) {
            shortCollateral += addedCollateral;
        }
    }

    function _updateOpenInterest(int256 addedVolume, int8 direction) internal {
        if (direction == LONG) {
            longOpenInterest += addedVolume;
        } else if (direction == SHORT) {
            shortOpenInterest += addedVolume;
        }
    }

    function _updateTotalAssets(int256 addedAssets, int8 direction) internal {
        if (direction == LONG) {
            longTotalAssets += addedAssets;
        } else if (direction == SHORT) {
            shortTotalAssets += addedAssets;
        }
    }

    function _deletePosition(uint256 id) internal {
        delete positions[id];
    }

    function _getValue(uint256 id, int256 price) internal view returns (uint256) {
        Position storage position = positions[id];

        int256 assetValue = position.assets * price * COLLATERAL_MULTIPLIER / ASSET_MULTIPLIER / GLOBAL_MULTIPLIER;
        int256 profit = (assetValue - position.entryVolume) * position.direction;
        int256 borrowFeeAmount = _getBorrowFeeAmount(position);
        int256 fundingFeeAmount = _getFundingFeeAmount(position);
        int256 value = int256(position.collateral) + profit - borrowFeeAmount - fundingFeeAmount;

        // A position can not have a negative value, as "after" liquidation nothing is left.
        if (value < 0) {
            return 0;
        }
        return uint256(value);
    }

    function _getBorrowFeeAmount(Position storage position_) internal view returns (int256) {
        return (totalBorrowFeeIntegral() - position_.borrowFeeIntegral) * position_.entryVolume / 10_000 / BPS;
    }

    function _getFundingFeeAmount(Position storage position_) internal view returns (int256) {
        return position_.direction * (totalFundingFeeIntegral() - position_.fundingFeeIntegral) * position_.entryVolume
            / 10_000 / BPS;
    }

    /**
     * @dev Returns price normalized to global decimals (10^30)
     */
    function _getPrice() internal view returns (int256) {
        PythStructs.Price memory priceData = pyth.getPriceNoOlderThan(pythId, 0);
        require(priceData.price > 0, "TradePair::_getPrice: Failed to fetch the current priceData.");
        if (priceData.expo > 0) {
            return int256(priceData.price) * int256(10 ** uint256(uint32(priceData.expo))) * GLOBAL_MULTIPLIER;
        } else {
            return int256(priceData.price) * GLOBAL_MULTIPLIER / int256(10 ** uint256(uint32(-1 * priceData.expo)));
        }
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

    function totalBorrowFeeIntegral() public view returns (int256) {
        return borrowFeeIntegral + unrealizedBorrowFeeIntegral();
    }

    function totalFundingFeeIntegral() public view returns (int256) {
        return fundingFeeIntegral + unrealizedFundingFeeIntegral();
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
