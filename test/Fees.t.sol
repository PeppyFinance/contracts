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

    function test_maxSkew_defaultsToFive() public {
        assertEq(tradePair.maxSkew(), 5 * BPS);
    }

    function test_borrowRate_nonZero() public {
        _liquidityPool_setMaxBorrowRate(5_000);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        assertEq(_tradePair_getBorrowRate(), 0, "borrow rate before");

        _openPosition(BOB, 100 ether, 1, _5X);

        // utilization is 50%
        assertEq(_tradePair_getBorrowRate(), 2_500, "borrow rate after");

        _openPosition(BOB, 100 ether, 1, _5X);

        // utilization is 100%
        assertEq(_tradePair_getBorrowRate(), 5_000, "borrow rate after");
    }

    function test_borrowRate_overUtilization() public {
        _liquidityPool_setMaxBorrowRate(5_000);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        assertEq(_tradePair_getBorrowRate(), 0, "borrow rate before");

        _openPosition(BOB, 400 ether, 1, _5X);

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

        _openPosition(BOB, 100 ether, 1, _5X);

        assertEq(_liquidityPool_getBorrowRate(), 3_000, "borrow rate 50% utlization");

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_liquidityPool_getBorrowRate(), 5_000, "borrow rate 100% utlization");

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_liquidityPool_getBorrowRate(), 7_000, "borrow rate 150% utlization");
    }

    function test_tradePair_borrowRate() public {
        _liquidityPool_setMinBorrowRate(1_000);
        _liquidityPool_setMaxBorrowRate(5_000);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_tradePair_getBorrowRate(), 3_000, "borrow rate 50% utlization");

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_tradePair_getBorrowRate(), 5_000, "borrow rate 100% utlization");

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_tradePair_getBorrowRate(), 7_000, "borrow rate 150% utlization");
    }

    function test_tradePair_borrowRate_withBalancedOpenInterest() public {
        _liquidityPool_setMinBorrowRate(1_000);
        _liquidityPool_setMaxBorrowRate(5_000);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 99999 ether, LONG, _5X);

        _openPosition(BOB, 99999 ether, SHORT, _5X);

        assertEq(_tradePair_getBorrowRate(), 1_000, "borrow rate 0% utlization");
    }

    function test_tradePair_updatesBorrowFeeIntegralOnOpen() public {
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);

        assertEq(_tradePair_getBorrowRate(), 1 * BPS, "borrow rate 0% utlization");

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_tradePair_borrowFeeIntegral(), 1 * BPS, "borrow fee integral at 1 hours");
        assertEq(_tradePair_getBorrowRate(), 3 * BPS, "borrow rate 50% utlization");

        vm.warp(2 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_tradePair_borrowFeeIntegral(), (1 + 3) * BPS, "borrow fee integral at 2 hours");
    }

    function test_tradePair_updatesBorrowFeeIntegralOnClose() public {
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);

        assertEq(_tradePair_getBorrowRate(), 1 * BPS, "borrow rate 0% utlization");

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_tradePair_borrowFeeIntegral(), 1 * BPS, "borrow fee integral at 1 hours");

        vm.warp(2 hours + 1);

        _closePosition(BOB, 1);
        assertEq(_tradePair_borrowFeeIntegral(), (1 + 3) * BPS, "borrow fee integral at 2 hours");
    }

    function test_tradePair_updatesBorrowFeeIntegralOnLiquidation() public {
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);

        assertEq(_tradePair_getBorrowRate(), 1 * BPS, "borrow rate 0% utlization");

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_tradePair_borrowFeeIntegral(), 1 * BPS, "borrow fee integral at 1 hours");
        _setPrice(address(collateralToken), 800 ether);

        vm.warp(2 hours + 1);

        _liquidatePosition(1);
        assertEq(_tradePair_borrowFeeIntegral(), (1 + 3) * BPS, "borrow fee integral at 2 hours");
    }

    function test_tradePair_setMaxFundingRate() public {
        _tradePair_setMaxFundingRate(5 * BPS);
        assertEq(tradePair.maxFundingRate(), 5 * BPS, "funding rate");
    }

    function test_fundingRate_isMaxFundingRateWhenOnlyOneSideHasOpenInterest() public {
        _tradePair_setMaxFundingRate(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "funding rate");
    }

    function test_fundingRate_zero_whenBalancedSkew() public {
        _tradePair_setMaxFundingRate(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);
        _openPosition(BOB, 100 ether, SHORT, _5X);
        assertEq(_tradePair_getFundingRate(), 0, "funding rate");
    }

    function test_tradePair_setMaxSkew() public {
        _tradePair_setMaxSkew(5 * BPS);
        assertEq(tradePair.maxSkew(), 5 * BPS, "skew");
    }

    function test_fundingRate_skew_long() public {
        _tradePair_setMaxFundingRate(5 * BPS);
        _tradePair_setMaxSkew(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);
        _openPosition(BOB, 50 ether, SHORT, _5X);
        _openPosition(BOB, 50 ether, SHORT, _5X);
        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 0, "funding rate should be 0");

        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 2 * BPS, "skew 2/1 of 5 funding rate should be 2");

        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 3 * BPS, "skew 3/1 of 5 funding rate should be 3");

        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 4 * BPS, "skew 4/1 of 5 funding rate should be 4");

        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "skew 5/1 of 5 funding rate should be 5");

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_tradePair_getFundingRate(), 6 * BPS, "skew 6/1 of 5 funding rate should be 6");

        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 7 * BPS, "skew 7/1 of 5 funding rate should be 7");

        _closePosition(BOB, 1);
        assertEq(_tradePair_getFundingRate(), 14 * BPS, "skew 7/0.5 of 5 funding rate should be 14");

        _closePosition(BOB, 2);
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "skew 7/0 of 5 funding rate should be 5 (max)");
    }

    function test_fundingRate_skew_short() public {
        _tradePair_setMaxFundingRate(5 * BPS);
        _tradePair_setMaxSkew(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);
        _openPosition(BOB, 50 ether, LONG, _5X);
        _openPosition(BOB, 50 ether, LONG, _5X);
        _openPosition(BOB, 100 ether, SHORT, _5X);
        assertEq(_tradePair_getFundingRate(), 0, "funding rate should be 0");

        _openPosition(BOB, 100 ether, SHORT, _5X);
        assertEq(_tradePair_getFundingRate(), -2 * BPS, "skew 2/1 of 5 funding rate should be -2");

        _openPosition(BOB, 100 ether, SHORT, _5X);
        assertEq(_tradePair_getFundingRate(), -3 * BPS, "skew 3/1 of 5 funding rate should be -3");

        _openPosition(BOB, 100 ether, SHORT, _5X);
        assertEq(_tradePair_getFundingRate(), -4 * BPS, "skew 4/1 of 5 funding rate should be -4");

        _openPosition(BOB, 100 ether, SHORT, _5X);
        assertEq(_tradePair_getFundingRate(), -5 * BPS, "skew 5/1 of 5 funding rate should be -5");

        _openPosition(BOB, 100 ether, SHORT, _5X);

        assertEq(_tradePair_getFundingRate(), -6 * BPS, "skew 6/1 of 5 funding rate should be -6");

        _openPosition(BOB, 100 ether, SHORT, _5X);
        assertEq(_tradePair_getFundingRate(), -7 * BPS, "skew 7/1 of 5 funding rate should be -7");

        _closePosition(BOB, 1);
        assertEq(_tradePair_getFundingRate(), -14 * BPS, "skew 7/0.5 of 5 funding rate should be -14");

        _closePosition(BOB, 2);
        assertEq(_tradePair_getFundingRate(), -5 * BPS, "skew 7/0 of 5 funding rate should be -5 (max)");
    }

    function test_fundingFeeIntegral_basic() public {
        _tradePair_setMaxFundingRate(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "funding rate should be 5");
        assertEq(_tradePair_fundingFeeIntegral(), 0, "funding fee integral at 1 hours");

        vm.warp(2 hours + 1);
        _closePosition(BOB, 1);
        assertEq(_tradePair_fundingFeeIntegral(), 5 * BPS, "funding fee integral at 2 hours");
    }

    function test_fundingFeeIntegral_updatesOnClose() public {
        _tradePair_setMaxFundingRate(5 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "funding rate should be 5");
        assertEq(_tradePair_fundingFeeIntegral(), 0, "funding fee integral at 1 hours");

        vm.warp(2 hours + 1);
        _closePosition(BOB, 1);
        assertEq(_tradePair_fundingFeeIntegral(), 5 * BPS, "funding fee integral at 2 hours");
    }
}
