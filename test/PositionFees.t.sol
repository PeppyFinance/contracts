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
        _setPrice(address(collateralToken), 1000 ether);

        vm.warp(1 hours);
        _openPosition(BOB, 100 ether, 1, _5X);

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
        _setPrice(address(collateralToken), 1000 ether);

        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, 1, _5X);

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
        _setPrice(address(collateralToken), 1000 ether);

        vm.warp(1 hours + 1);
        _openPosition(BOB, 100 ether, 1, _5X);

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
}
