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

contract PositionPnLTest is Test, WithHelpers {
    function setUp() public {
        _deployTestSetup();
    }

    function test_pnl_profit_long() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 100 ether, LONG, _5X);

        _setPrice(address(collateralToken), 1200 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), 200 ether, "should have made 100% profit");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 900 ether, "LP should pay out 100% profit");
    }

    function test_pnl_profit_short() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 100 ether, SHORT, _5X);

        _setPrice(address(collateralToken), 800 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), 200 ether, "should have made 100% profit");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 900 ether, "LP should pay out 100% profit");
    }

    function test_pnl_loss_long() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 100 ether, LONG, _5X);

        _setPrice(address(collateralToken), 900 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), 50 ether, "should have lost 50%");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1050 ether, "LP should receive loss");
    }

    function test_pnl_loss_short() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 100 ether, SHORT, _5X);

        _setPrice(address(collateralToken), 1100 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), 50 ether, "should have lost 50%");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1050 ether, "LP should receive loss");
    }

    function test_pnl_withFees_profit_long() public {
        _tradePair_setOpenFee(10 * BPS);
        _tradePair_setCloseFee(10 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _tradePair_setMaxFundingRate(5 * BPS);

        _deposit(ALICE, 999.5 ether); // will receive 0.5 from open fee
        _setPrice(address(collateralToken), 1000 ether);

        vm.warp(1 hours);

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_liquidityPool_getBorrowRate(), 3 * BPS, "borrow rate should be 3%");
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "funding rate should be 5%");

        vm.warp(2 hours);

        uint256 feeAmount = 8 * 100 ether * 5 / 10_000;
        uint256 value = 200 ether - feeAmount;
        uint256 closeFee = value * 10 / 10_000;
        uint256 payOut = value - closeFee;

        _setPrice(address(collateralToken), 1200 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), payOut, "should be payout");
        assertEq(
            collateralToken.balanceOf(address(liquidityPool)),
            1000 ether + 100 ether - payOut,
            "LP should pay out 80% profit"
        );
    }

    function test_pnl_withFees_profit_short() public {
        _tradePair_setOpenFee(10 * BPS);
        _tradePair_setCloseFee(10 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _tradePair_setMaxFundingRate(5 * BPS);

        _deposit(ALICE, 999.5 ether); // will receive 0.5 from open fee
        _setPrice(address(collateralToken), 1000 ether);

        vm.warp(1 hours);

        _openPosition(BOB, 100 ether, SHORT, _5X);

        assertEq(_liquidityPool_getBorrowRate(), 3 * BPS, "borrow rate should be 3%");
        assertEq(_tradePair_getFundingRate(), -5 * BPS, "funding rate should be 5%");

        vm.warp(2 hours);

        uint256 feeAmount = 8 * 100 ether * 5 / 10_000;
        uint256 value = 200 ether - feeAmount;
        uint256 closeFee = value * 10 / 10_000;
        uint256 payOut = value - closeFee;

        _setPrice(address(collateralToken), 800 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), payOut, "should be payout");
        assertEq(
            collateralToken.balanceOf(address(liquidityPool)),
            1000 ether + 100 ether - payOut,
            "LP should pay out 80% profit"
        );
    }

    function test_pnl_withFees_loss_long() public {
        _tradePair_setOpenFee(10 * BPS);
        _tradePair_setCloseFee(10 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _tradePair_setMaxFundingRate(5 * BPS);

        _deposit(ALICE, 999.5 ether); // will receive 0.5 from open fee
        _setPrice(address(collateralToken), 1000 ether);

        vm.warp(1 hours);

        _openPosition(BOB, 100 ether, LONG, _5X);

        assertEq(_liquidityPool_getBorrowRate(), 3 * BPS, "borrow rate should be 3%");
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "funding rate should be 5%");

        vm.warp(2 hours);

        uint256 feeAmount = 8 * 100 ether * 5 / 10_000;
        uint256 value = 50 ether - feeAmount;
        uint256 closeFee = value * 10 / 10_000;
        uint256 payOut = value - closeFee;

        _setPrice(address(collateralToken), 900 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), payOut, "should be payout");
        assertEq(
            collateralToken.balanceOf(address(liquidityPool)), 1000 ether + 100 ether - payOut, "LP should receive loss"
        );
    }

    function test_pnl_withFees_loss_short() public {
        _tradePair_setOpenFee(10 * BPS);
        _tradePair_setCloseFee(10 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _tradePair_setMaxFundingRate(5 * BPS);

        _deposit(ALICE, 999.5 ether); // will receive 0.5 from open fee
        _setPrice(address(collateralToken), 1000 ether);

        vm.warp(1 hours);

        _openPosition(BOB, 100 ether, SHORT, _5X);

        assertEq(_liquidityPool_getBorrowRate(), 3 * BPS, "borrow rate should be 3%");
        assertEq(_tradePair_getFundingRate(), -5 * BPS, "funding rate should be 5%");

        vm.warp(2 hours);

        uint256 feeAmount = 8 * 100 ether * 5 / 10_000;
        uint256 value = 50 ether - feeAmount;
        uint256 closeFee = value * 10 / 10_000;
        uint256 payOut = value - closeFee;

        _setPrice(address(collateralToken), 1100 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), payOut, "should be payout");
        assertEq(
            collateralToken.balanceOf(address(liquidityPool)), 1000 ether + 100 ether - payOut, "LP should receive loss"
        );
    }
}
