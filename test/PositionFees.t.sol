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

contract PositionFeesTest is Test, WithHelpers {
    function setUp() public {
        _deployTestSetup();
    }

    function test_positionDetails_basic() public {
        _deposit(ALICE, 500 ether);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _setPrice(1000 * 1e8);

        vm.warp(1 hours);
        _openPosition(BOB, 100 ether, LONG, _5X);

        ITradePair.PositionDetails memory positionDetails = _tradePair_getPositionDetails(1);

        assertEq(positionDetails.collateral, 100 ether, "collateral");
        assertEq(positionDetails.entryVolume, 500 ether, "entryVolume");
        assertEq(positionDetails.assets, 0.5 ether, "assets");
        assertEq(positionDetails.direction, LONG, "direction");
        assertEq(positionDetails.entryTimestamp, 1 hours, "entryTimestamp");
        assertEq(positionDetails.borrowFeeAmount, 0, "borrowFeeAmount");
        assertEq(positionDetails.fundingFeeAmount, 0, "fundingFeeAmount");
        assertEq(positionDetails.owner, BOB, "owner");
        assertEq(positionDetails.value, 100 ether, "value");
    }

    function test_positionDetails_affectedByBorrowFee() public {
        _deposit(ALICE, 500 ether);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _setPrice(1000 * 1e8);

        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);

        vm.warp(2 hours + 1);
        assertEq(_liquidityPool_getBorrowRate(), 5 * BPS, "borrowRate is at max");

        int256 expectedBorrowFeeAmount = 5 * 100 ether * 5 / 10000;

        ITradePair.PositionDetails memory positionDetails = _tradePair_getPositionDetails(1);

        assertEq(positionDetails.collateral, 100 ether, "collateral");
        assertEq(positionDetails.entryVolume, 500 ether, "entryVolume");
        assertEq(positionDetails.assets, 0.5 ether, "assets");
        assertEq(positionDetails.direction, LONG, "direction");
        assertEq(positionDetails.entryTimestamp, 1 hours + 1, "entryTimestamp");
        assertEq(positionDetails.borrowFeeAmount, expectedBorrowFeeAmount, "borrowFeeAmount");
        assertEq(positionDetails.fundingFeeAmount, 0, "fundingFeeAmount");
        assertEq(positionDetails.owner, BOB, "owner");
        assertEq(positionDetails.value, 100 ether - uint256(expectedBorrowFeeAmount), "value");
    }

    function test_positionDetails_affectedByFundingFee() public {
        _deposit(ALICE, 500 ether);
        _tradePair_setMaxFundingRate(5 * BPS);
        _setPrice(1000 * 1e8);

        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);

        vm.warp(2 hours + 1);
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "borrowRate is at max");

        int256 expectedFundingFeeAmount = 5 * 100 ether * 5 / 10000;

        ITradePair.PositionDetails memory positionDetails = _tradePair_getPositionDetails(1);

        assertEq(positionDetails.collateral, 100 ether, "collateral");
        assertEq(positionDetails.entryVolume, 500 ether, "entryVolume");
        assertEq(positionDetails.assets, 0.5 ether, "assets");
        assertEq(positionDetails.direction, LONG, "direction");
        assertEq(positionDetails.entryTimestamp, 1 hours + 1, "entryTimestamp");
        assertEq(positionDetails.borrowFeeAmount, 0, "borrowFeeAmount");
        assertEq(positionDetails.fundingFeeAmount, expectedFundingFeeAmount, "fundingFeeAmount");
        assertEq(positionDetails.owner, BOB, "owner");
        assertEq(positionDetails.value, 100 ether - uint256(expectedFundingFeeAmount), "value");
    }

    function test_positionDetails_affectedByBothFees() public {
        _deposit(ALICE, 500 ether);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _tradePair_setMaxFundingRate(5 * BPS);
        _setPrice(1000 * 1e8);

        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);

        vm.warp(2 hours + 1);
        assertEq(_liquidityPool_getBorrowRate(), 5 * BPS, "borrowRate is at max");
        assertEq(_tradePair_getFundingRate(), 5 * BPS, "borrowRate is at max");

        int256 expectedBorrowFeeAmount = 5 * 100 ether * 5 / 10000;
        int256 expectedFundingFeeAmount = 5 * 100 ether * 5 / 10000;

        ITradePair.PositionDetails memory positionDetails = _tradePair_getPositionDetails(1);

        assertEq(positionDetails.collateral, 100 ether, "collateral");
        assertEq(positionDetails.entryVolume, 500 ether, "entryVolume");
        assertEq(positionDetails.assets, 0.5 ether, "assets");
        assertEq(positionDetails.direction, LONG, "direction");
        assertEq(positionDetails.entryTimestamp, 1 hours + 1, "entryTimestamp");
        assertEq(positionDetails.borrowFeeAmount, expectedBorrowFeeAmount, "borrowFeeAmount");
        assertEq(positionDetails.fundingFeeAmount, expectedFundingFeeAmount, "fundingFeeAmount");
        assertEq(positionDetails.owner, BOB, "owner");
        assertEq(
            positionDetails.value, 100 ether - uint256(expectedBorrowFeeAmount + expectedFundingFeeAmount), "value"
        );
    }

    function test_positionDetails_twoPeriods() public {
        _deposit(ALICE, 500 ether);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _tradePair_setMaxFundingRate(5 * BPS);
        _setPrice(1000 * 1e8);

        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);
        _openPosition(BOB, 200 ether, SHORT, _5X);

        int256 borrowRate_period_1 = 5 * BPS;
        int256 fundingRate_period_1 = -2 * BPS;

        assertEq(_liquidityPool_getBorrowRate(), borrowRate_period_1, "borrowRate period 1");
        assertEq(_tradePair_getFundingRate(), fundingRate_period_1, "fundingRate period 1");

        vm.warp(2 hours + 1);

        _closePosition(BOB, 2);

        int256 borrowRate_period_2 = 4994407; // Fees from period 1 increase assets in LP, utilization decreases
        int256 fundingRate_period_2 = 5 * BPS;

        assertEq(_liquidityPool_getBorrowRate(), borrowRate_period_2, "borrowRate period 2");
        assertEq(_tradePair_getFundingRate(), fundingRate_period_2, "fundingRate period 2");

        vm.warp(3 hours + 1);

        ITradePair.PositionDetails memory positionDetails = _tradePair_getPositionDetails(1);

        int256 expectedBorrowFeeAmount = 5 * 100 ether * (borrowRate_period_1 + borrowRate_period_2) / 10000 / BPS;
        int256 expectedFundingFeeAmount = 5 * 100 ether * (fundingRate_period_1 + fundingRate_period_2) / 10000 / BPS;

        assertEq(positionDetails.collateral, 100 ether, "collateral");
        assertEq(positionDetails.entryVolume, 500 ether, "entryVolume");
        assertEq(positionDetails.assets, 0.5 ether, "assets");
        assertEq(positionDetails.direction, LONG, "direction");
        assertEq(positionDetails.entryTimestamp, 1 hours + 1, "entryTimestamp");
        assertEq(positionDetails.borrowFeeAmount, expectedBorrowFeeAmount, "borrowFeeAmount");
        assertEq(positionDetails.fundingFeeAmount, expectedFundingFeeAmount, "fundingFeeAmount");
        assertEq(positionDetails.owner, BOB, "owner");
        assertEq(
            positionDetails.value, 100 ether - uint256(expectedBorrowFeeAmount + expectedFundingFeeAmount), "value"
        );
    }

    function test_positionDetails_negativeFundingRate() public {
        _deposit(ALICE, 500 ether);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _tradePair_setMaxFundingRate(5 * BPS);
        _setPrice(1000 * 1e8);

        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);
        _openPosition(BOB, 200 ether, SHORT, _5X);

        int256 borrowRate_period_1 = 5 * BPS;
        int256 fundingRate_period_1 = -2 * BPS;

        assertEq(_liquidityPool_getBorrowRate(), borrowRate_period_1, "borrowRate period 1");
        assertEq(_tradePair_getFundingRate(), fundingRate_period_1, "fundingRate period 1");

        vm.warp(2 hours + 1);

        // Funding Fee is negative, should be a rebate here

        ITradePair.PositionDetails memory positionDetails = _tradePair_getPositionDetails(1);

        int256 expectedBorrowFeeAmount = 5 * 100 ether * borrowRate_period_1 / 10000 / BPS;
        int256 expectedFundingFeeAmount = 5 * 100 ether * fundingRate_period_1 / 10000 / BPS;

        assertEq(positionDetails.collateral, 100 ether, "collateral");
        assertEq(positionDetails.entryVolume, 500 ether, "entryVolume");
        assertEq(positionDetails.assets, 0.5 ether, "assets");
        assertEq(positionDetails.direction, LONG, "direction");
        assertEq(positionDetails.entryTimestamp, 1 hours + 1, "entryTimestamp");
        assertEq(positionDetails.borrowFeeAmount, expectedBorrowFeeAmount, "borrowFeeAmount");
        assertEq(positionDetails.fundingFeeAmount, expectedFundingFeeAmount, "fundingFeeAmount");
        assertEq(positionDetails.owner, BOB, "owner");
        assertEq(
            positionDetails.value, 100 ether - uint256(expectedBorrowFeeAmount + expectedFundingFeeAmount), "value"
        );
    }

    function test_position_paysFeesToLp() public {
        _deposit(ALICE, 500 ether);
        _liquidityPool_setMaxBorrowRate(5 * BPS);
        _liquidityPool_setMinBorrowRate(1 * BPS);
        _tradePair_setMaxFundingRate(5 * BPS);
        _setPrice(1000 * 1e8);

        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, LONG, _5X);
        _openPosition(BOB, 200 ether, SHORT, _5X);

        int256 borrowRate_period_1 = 5 * BPS;
        int256 fundingRate_period_1 = -2 * BPS;

        assertEq(_liquidityPool_getBorrowRate(), borrowRate_period_1, "borrowRate period 1");
        assertEq(_tradePair_getFundingRate(), fundingRate_period_1, "fundingRate period 1");

        vm.warp(2 hours + 1);

        assertEq(collateralToken.balanceOf(address(liquidityPool)), 500 ether, "lp balance before position 1");
        uint256 feeAmount_position_1 =
            uint256(5 * 100 ether * (borrowRate_period_1 + fundingRate_period_1) / 10000 / BPS);

        _closePosition(BOB, 1);

        assertEq(
            collateralToken.balanceOf(address(liquidityPool)),
            500 ether + feeAmount_position_1,
            "lp balance after position 1 closed"
        );

        uint256 feeAmount_position_2 =
            uint256(5 * 200 ether * (borrowRate_period_1 - fundingRate_period_1) / 10000 / BPS);

        _closePosition(BOB, 2);

        assertEq(
            collateralToken.balanceOf(address(liquidityPool)),
            500 ether + feeAmount_position_1 + feeAmount_position_2,
            "lp balance after position 2 closed"
        );
    }
}
