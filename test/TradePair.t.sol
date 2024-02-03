// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "src/Controller.sol";
import "test/setup/MockPriceFeed.sol";
import "test/setup/constants.sol";
import "test/setup/WithHelpers.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract TradePairBasicTest is Test, WithHelpers {
    function setUp() public {
        _deployTestSetup();
    }

    function test_totalOpenInterest() public {
        assertEq(tradePair.totalOpenInterest(), 0);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        assertEq(tradePair.totalOpenInterest(), 500 ether);
        _setPrice(address(collateralToken), 1200 ether);
        assertEq(tradePair.totalOpenInterest(), 500 ether);
        _closePosition(BOB, 1);
        assertEq(tradePair.totalOpenInterest(), 0);
    }

    function test_unrealizedPnL() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        assertEq(_tradePair_unrealizedPnL(), 0);
        _setPrice(address(collateralToken), 1200 ether);
        assertEq(_tradePair_unrealizedPnL(), 100 ether);
        _closePosition(BOB, 1);
        assertEq(_tradePair_unrealizedPnL(), 0);
    }

    function test_syncUnrealizedPnL_basic() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        _setPrice(address(collateralToken), 1200 ether);

        assertEq(collateralToken.balanceOf(address(tradePair)), 100 ether, "tradePair balance before");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1000 ether, "liquidityPool balance before");
        assertEq(_tradePair_unrealizedPnL(), 100 ether);

        _tradePair_syncUnrealizedPnL();

        assertEq(collateralToken.balanceOf(address(tradePair)), 200 ether, "tradePair balance after");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 900 ether, "liquidityPool balance after");
        assertEq(_tradePair_unrealizedPnL(), 100 ether);
    }

    function test_totalCollateral() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        assertEq(_tradePair_totalCollateral(), 100 ether);
        _setPrice(address(collateralToken), 1200 ether);
        assertEq(_tradePair_totalCollateral(), 100 ether);
        _closePosition(BOB, 1);
        assertEq(_tradePair_totalCollateral(), 0);
    }

    function test__syncUnrealizedPnL_complex() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        _setPrice(address(collateralToken), 1250 ether);

        _openPosition(BOB, 100 ether, 1, 5_000_000);
        _setPrice(address(collateralToken), 1500 ether);

        // 100 * 250% + 100 * 100%
        assertEq(_tradePair_unrealizedPnL(), 350 ether, "unrealizedPnL before");

        _tradePair_syncUnrealizedPnL();

        // 200 + 350
        assertEq(collateralToken.balanceOf(address(tradePair)), 550 ether, "tradePair balance before");

        // 1000 - 350
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 650 ether, "liquidityPool balance before");
    }
}
