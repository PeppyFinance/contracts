// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "test/setup/MockPriceFeed.sol";
import "test/setup/constants.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract Simulation is Test {
    TradePair tradePair;
    MockPriceFeed priceFeed;
    ERC20 collateralToken;
    LiquidityPool liquidityPool;

    function setUp() public {
        collateralToken = new ERC20("Collateral", "COLL");
        priceFeed = new MockPriceFeed();
        liquidityPool = new LiquidityPool(collateralToken);
        tradePair = new TradePair(collateralToken, priceFeed, liquidityPool);
    }

    function test_deposit() public {
        _deposit(ALICE, 1000 ether);
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1000 ether);
        assertEq(liquidityPool.balanceOf(ALICE), 1000 ether);
    }

    function test_redeem() public {
        _deposit(ALICE, 1000 ether);
        _redeem(ALICE, 500 ether);
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 500 ether);
        assertEq(liquidityPool.balanceOf(ALICE), 500 ether);
    }

    function test_openPosition() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1000 ether, "lp assets");
        assertEq(liquidityPool.balanceOf(ALICE), 1000 ether, "alice lp balance");
        assertEq(tradePair.longOpenInterest(), 500 ether, "long open interest");
        assertEq(tradePair.shortOpenInterest(), 0 ether, "short open interest");
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

    function _logState() internal {
        emit log_named_decimal_uint(
            padStringToLength("alice collateral balance", 30), collateralToken.balanceOf(ALICE), 18
        );
        emit log_named_decimal_uint(padStringToLength("alice lp balance", 30), liquidityPool.balanceOf(ALICE), 18);
        emit log_named_decimal_uint(
            padStringToLength("lp assets", 30), collateralToken.balanceOf(address(liquidityPool)), 18
        );
        emit log_named_decimal_uint(padStringToLength("lp total supply", 30), liquidityPool.totalSupply(), 18);
    }

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
