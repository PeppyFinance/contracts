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

contract FeesTest is Test, WithHelpers {
    function setUp() public {
        _deployTestSetup();
    }

    function test_borrowRate_zero() public {
        _deposit(ALICE, 1000 ether);
        assertEq(_tradePair_getBorrowRate(), 0);
    }

    function test_fundingRate_zero() public {
        _deposit(ALICE, 1000 ether);
        assertEq(_tradePair_getFundingRate(), 0);
    }

    function test_borrowRate_nonZero() public {
        _liquidityPool_setMaxBorrowRate(5_000);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        assertEq(_tradePair_getBorrowRate(), 0, "borrow rate before");

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        // utilization is 50%
        assertEq(_tradePair_getBorrowRate(), 2_500, "borrow rate after");

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        // utilization is 100%
        assertEq(_tradePair_getBorrowRate(), 5_000, "borrow rate after");
    }

    function test_borrowRate_overUtilization() public {
        _liquidityPool_setMaxBorrowRate(5_000);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        assertEq(_tradePair_getBorrowRate(), 0, "borrow rate before");

        _openPosition(BOB, 400 ether, 1, 5_000_000);

        // utilization is 200%
        assertEq(_tradePair_getBorrowRate(), 10_000, "borrow rate after");
    }

    function test_borrowRate_minimum() public {
        assertEq(_liquidityPool_getBorrowRate(), 0, "borrow rate before");
        _liquidityPool_setMinBorrowRate(500);
        _liquidityPool_setMaxBorrowRate(5_000);
        assertEq(_liquidityPool_getBorrowRate(), 500, "borrow rate after");
        _deposit(ALICE, 1000 ether);
        assertEq(_liquidityPool_getBorrowRate(), 500, "borrow rate after deposit");
    }

    function test_borrowRate_utilization() public {
        _liquidityPool_setMinBorrowRate(1_000);
        _liquidityPool_setMaxBorrowRate(5_000);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        assertEq(_liquidityPool_getBorrowRate(), 3_000, "borrow rate 50% utlization");

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        assertEq(_liquidityPool_getBorrowRate(), 5_000, "borrow rate 100% utlization");

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        assertEq(_liquidityPool_getBorrowRate(), 7_000, "borrow rate 150% utlization");
    }

    function test_tradePair_borrowRate() public {
        _liquidityPool_setMinBorrowRate(1_000);
        _liquidityPool_setMaxBorrowRate(5_000);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        assertEq(_tradePair_getBorrowRate(), 3_000, "borrow rate 50% utlization");

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        assertEq(_tradePair_getBorrowRate(), 5_000, "borrow rate 100% utlization");

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        assertEq(_tradePair_getBorrowRate(), 7_000, "borrow rate 150% utlization");
    }
}
