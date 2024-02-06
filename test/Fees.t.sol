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
}
