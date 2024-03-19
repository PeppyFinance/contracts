// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "src/Controller.sol";
import "pyth-sdk-solidity/MockPyth.sol";
import "test/setup/constants.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract WithHelpers is Test {
    Controller controller;
    TradePair tradePair;
    MockPyth mockPyth;
    ERC20 collateralToken;
    LiquidityPool liquidityPool;

    event TradePairConstructed(
        address collateralToken,
        address pyth,
        uint8 assetDecimals,
        uint8 collateralDecimals,
        bytes32 pythId,
        string name
    );

    function test_WithHelpers() public {}

    function _deployTestSetup() public {
        controller = new Controller();
        collateralToken = new ERC20("Collateral", "COLL");
        mockPyth = new MockPyth(10, 1);
        liquidityPool = new LiquidityPool(controller, collateralToken);
        tradePair = new TradePair(controller, liquidityPool, 18, 18, address(mockPyth), PYTH_IOTA_USD, "IOTAUSD");
        controller.addTradePair(address(tradePair));
        deal(address(this), 1 ether);
    }

    // Helper functions
    /// @dev sets price for IOTA/USD
    function _setPrice(int64 price_) internal {
        deal(msg.sender, 1 ether);
        _setPrice(PYTH_IOTA_USD, price_, -8);
    }

    function _getPythUpdateArrayWithCurrentPrice() internal view returns (bytes[] memory) {
        bytes memory updateData = MockPyth(address(mockPyth)).createPriceFeedUpdateData(
            PYTH_IOTA_USD, _getPrice(), 456, -8, 120, 400, uint64(block.timestamp)
        );

        bytes[] memory updateDataArray = new bytes[](1);
        updateDataArray[0] = updateData;
        return updateDataArray;
    }

    function _setPrice(bytes32 id_, int64 price_, int32 expo_) internal {
        bytes memory updateData = MockPyth(address(mockPyth)).createPriceFeedUpdateData(
            id_, price_, 456, expo_, 120, 400, uint64(block.timestamp)
        );

        bytes[] memory updateDataArray = new bytes[](1);
        updateDataArray[0] = updateData;

        mockPyth.updatePriceFeeds{value: 1}(updateDataArray);
    }

    function _getPrice() internal view returns (int64) {
        return _getPrice(PYTH_IOTA_USD);
    }

    function _getPrice(bytes32 id) internal view returns (int64) {
        return mockPyth.getPriceUnsafe(id).price;
    }

    function _redeem(address trader, uint256 amount) internal {
        vm.startPrank(trader);
        liquidityPool.redeem(amount);
        vm.stopPrank();
    }

    function _deposit(address trader, uint256 amount) internal {
        deal(address(collateralToken), trader, amount);
        vm.startPrank(trader);
        collateralToken.approve(address(liquidityPool), amount);
        liquidityPool.deposit(amount);
        vm.stopPrank();
    }

    function _openPosition(address trader, uint256 collateral, int8 direction, uint256 leverage) internal {
        uint256 openFeeAmount = (collateral * leverage * uint256(tradePair.openFee())) / 10_000 / 1e6 / uint256(BPS);
        deal(address(collateralToken), trader, collateral + openFeeAmount);
        deal(trader, 1 ether);

        vm.startPrank(trader);
        collateralToken.approve(address(tradePair), collateral + openFeeAmount);
        tradePair.openPosition{value: 1}(collateral, leverage, direction, _getPythUpdateArrayWithCurrentPrice());
        vm.stopPrank();
    }

    function _closePosition(address trader, uint256 id) internal {
        deal(trader, 1 ether);
        vm.startPrank(trader);
        tradePair.closePosition{value: 1}(id, _getPythUpdateArrayWithCurrentPrice());
        vm.stopPrank();
    }

    function _liquidatePosition(uint256 id) internal {
        tradePair.liquidatePosition{value: 1}(id, _getPythUpdateArrayWithCurrentPrice());
    }

    function _tradePair_unrealizedPnL() internal returns (int256) {
        return tradePair.getUnrealizedPnL{value: 1}(_getPythUpdateArrayWithCurrentPrice());
    }

    function _tradePair_syncUnrealizedPnL() internal {
        tradePair.syncUnrealizedPnL{value: 1}(_getPythUpdateArrayWithCurrentPrice());
    }

    function _tradePair_totalCollateral() internal view returns (int256) {
        return tradePair.totalCollateral();
    }

    function _tradePair_getBorrowRate() internal view returns (int256) {
        return tradePair.getBorrowRate();
    }

    function _tradePair_getFundingRate() internal view returns (int256) {
        return tradePair.getFundingRate();
    }

    function _tradePair_borrowFeeIntegral() internal view returns (int256) {
        return tradePair.borrowFeeIntegral();
    }

    function _tradePair_fundingFeeIntegral() internal view returns (int256) {
        return tradePair.fundingFeeIntegral();
    }

    function _tradePair_setMaxFundingRate(int256 rate) internal {
        tradePair.setMaxFundingRate(rate);
    }

    function _tradePair_setMaxSkew(int256 maxSkew) internal {
        tradePair.setMaxSkew(maxSkew);
    }

    function _tradePair_setOpenFee(int256 fee) internal {
        tradePair.setOpenFee(fee);
    }

    function _tradePair_setCloseFee(int256 fee) internal {
        tradePair.setCloseFee(fee);
    }

    function _tradePair_setMaxPriceAge(uint256 maxPriceAge_) internal {
        tradePair.setMaxPriceAge(maxPriceAge_);
    }

    function _tradePair_getPositionDetails(uint256 id) internal view returns (ITradePair.PositionDetails memory) {
        return tradePair.getPositionDetails(id, int256(_getPrice(PYTH_IOTA_USD)) * 1e30 / 1e8);
    }

    function _tradePair_unrealizedBorrowFeeIntegral() internal view returns (int256) {
        return tradePair.unrealizedBorrowFeeIntegral();
    }

    function _tradePair_unrealizedFundingFeeIntegral() internal view returns (int256) {
        return tradePair.unrealizedFundingFeeIntegral();
    }

    function _tradePair_totalBorrowFeeIntegral() internal view returns (int256) {
        return tradePair.totalBorrowFeeIntegral();
    }

    function _tradePair_totalFundingFeeIntegral() internal view returns (int256) {
        return tradePair.totalFundingFeeIntegral();
    }

    function _liquidityPool_setMaxBorrowRate(int256 rate) internal {
        liquidityPool.setMaxBorrowRate(rate);
    }

    function _liquidityPool_setMinBorrowRate(int256 rate) internal {
        liquidityPool.setMinBorrowRate(rate);
    }

    function _liquidityPool_getBorrowRate() internal view returns (int256) {
        return liquidityPool.getBorrowRate(tradePair.excessOpenInterest());
    }

    // Log functions

    function _logState(string memory message) internal {
        if (!vm.envOr("LOG_SIMULATION", false)) {
            return;
        }
        emit log_string("");
        emit log_string(message);
        _logState();
    }

    function _logState() internal {
        if (!vm.envOr("LOG_SIMULATION", false)) {
            return;
        }
        emit log_named_decimal_uint(
            padStringToLength("alice collateral balance", 30), collateralToken.balanceOf(ALICE), 18
        );
        emit log_named_decimal_uint(padStringToLength("dan collateral balance", 30), collateralToken.balanceOf(DAN), 18);
        emit log_named_decimal_uint(
            padStringToLength("tradepair collateral balance", 30), collateralToken.balanceOf(address(tradePair)), 18
        );
        emit log_named_decimal_uint(padStringToLength("alice lp balance", 30), liquidityPool.balanceOf(ALICE), 18);
        emit log_named_decimal_uint(
            padStringToLength("alice lp claim", 30), liquidityPool.previewRedeem(liquidityPool.balanceOf(ALICE)), 18
        );
        emit log_named_decimal_uint(
            padStringToLength("dan lp claim", 30), liquidityPool.previewRedeem(liquidityPool.balanceOf(DAN)), 18
        );
        emit log_named_decimal_uint(
            padStringToLength("lp assets", 30), collateralToken.balanceOf(address(liquidityPool)), 18
        );
        emit log_named_decimal_uint(padStringToLength("lp total supply", 30), liquidityPool.totalSupply(), 18);
    }

    /**
     * @dev Pads a string to a specified length.
     * If the input string is shorter than the specified length, it is padded with spaces.
     * If the input string is longer or equal to the specified length, it is returned as is.
     *
     * @param input The string to be padded.
     * @param X The desired length of the output string.
     * @return A string of length X. If the input string is shorter than X, it is padded with spaces.
     */
    function padStringToLength(string memory input, uint256 X) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        if (inputBytes.length >= X) {
            return input;
        }

        bytes memory padded = new bytes(X);
        for (uint256 i = 0; i < X; i++) {
            if (i < inputBytes.length) {
                padded[i] = inputBytes[i];
            } else {
                padded[i] = 0x20; // AS II code for space
            }
        }

        return string(padded);
    }
}
