// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "src/Controller.sol";
import "test/setup/MockPriceFeed.sol";
import "test/setup/constants.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract WithHelpers is Test {
    Controller controller;
    TradePair tradePair;
    MockPriceFeed priceFeed;
    ERC20 collateralToken;
    LiquidityPool liquidityPool;

    function test_WithHelpers() public {}

    function _deployTestSetup() public {
        controller = new Controller();
        collateralToken = new ERC20("Collateral", "COLL");
        priceFeed = new MockPriceFeed();
        liquidityPool = new LiquidityPool(controller, collateralToken);
        tradePair = new TradePair(controller, collateralToken, priceFeed, liquidityPool, 18);
        controller.addTradePair(address(tradePair));
    }

    // Helper functions

    function _setPrice(address token, int256 price) internal {
        priceFeed.setPrice(token, price);
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
        deal(address(collateralToken), trader, collateral);

        vm.startPrank(trader);
        collateralToken.approve(address(tradePair), collateral);
        tradePair.openPosition(collateral, leverage, direction, new bytes[](0));
        vm.stopPrank();
    }

    function _closePosition(address trader, uint256 id) internal {
        vm.startPrank(trader);
        tradePair.closePosition(id, new bytes[](0));
        vm.stopPrank();
    }

    function _liquidatePosition(uint256 id) internal {
        tradePair.liquidatePosition(id, new bytes[](0));
    }

    function _tradePair_unrealizedPnL() internal returns (int256) {
        return tradePair.unrealizedPnL(new bytes[](0));
    }

    function _tradePair_syncUnrealizedPnL() internal {
        tradePair.syncUnrealizedPnL(new bytes[](0));
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
        return tradePair.borrowFeeIntegral();
    }

    function _tradePair_setMaxFundingRate(int256 rate) internal {
        tradePair.setMaxFundingRate(rate);
    }

    function _tradePair_setMaxSkew(int256 maxSkew) internal {
        tradePair.setMaxSkew(maxSkew);
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
