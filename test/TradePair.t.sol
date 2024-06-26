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
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        assertEq(tradePair.totalOpenInterest(), 500 ether);
        vm.warp(2);
        _setPrice(1200 * 1e8);
        assertEq(tradePair.totalOpenInterest(), 500 ether);
        _closePosition(BOB, 1);
        assertEq(tradePair.totalOpenInterest(), 0);
    }

    function test_unrealizedPnL() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        assertEq(_tradePair_unrealizedPnL(), 0);
        vm.warp(2);
        _setPrice(1200 * 1e8);
        assertEq(_tradePair_unrealizedPnL(), 100 ether);
        _closePosition(BOB, 1);
        assertEq(_tradePair_unrealizedPnL(), 0);
    }

    function test_syncUnrealizedPnL_basic() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        vm.warp(2);
        _setPrice(1200 * 1e8);

        assertEq(collateralToken.balanceOf(address(tradePair)), 100 ether, "tradePair balance before");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1000 ether, "liquidityPool balance before");
        assertEq(_tradePair_unrealizedPnL(), 100 ether);

        _tradePair_syncUnrealizedPnL();

        assertEq(collateralToken.balanceOf(address(tradePair)), 200 ether, "tradePair balance after");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 900 ether, "liquidityPool balance after");
        assertEq(_tradePair_unrealizedPnL(), 100 ether);
    }

    function test_syncUnrealizedPnL_positiveExpo() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(PYTH_IOTA_USD, 1000 * 1e8, 8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        vm.warp(2);
        _setPrice(PYTH_IOTA_USD, 1200 * 1e8, 8);

        assertEq(collateralToken.balanceOf(address(tradePair)), 100 ether, "tradePair balance before");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1000 ether, "liquidityPool balance before");
        assertEq(_tradePair_unrealizedPnL(), 100 ether);

        _tradePair_syncUnrealizedPnL();

        assertEq(collateralToken.balanceOf(address(tradePair)), 200 ether, "tradePair balance after");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 900 ether, "liquidityPool balance after");
        assertEq(_tradePair_unrealizedPnL(), 100 ether);
    }

    function test_fail_nullPrice() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(PYTH_IOTA_USD, 0, 8);

        deal(address(collateralToken), BOB, 100 ether);

        deal(BOB, 1);
        vm.startPrank(BOB);
        collateralToken.approve(address(tradePair), 100 ether);
        bytes[] memory updateDataArray = _getPythUpdateArrayWithCurrentPrice();

        vm.expectRevert("TradePair::_getPrice: Failed to fetch the current priceData.");
        tradePair.openPosition{value: 1}(100 ether, _5X, LONG, updateDataArray);
    }

    function test_totalCollateral() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        assertEq(_tradePair_totalCollateral(), 100 ether);
        vm.warp(2);
        _setPrice(1200 * 1e8);
        assertEq(_tradePair_totalCollateral(), 100 ether);
        _closePosition(BOB, 1);
        assertEq(_tradePair_totalCollateral(), 0);
    }

    function test__syncUnrealizedPnL_complex() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        vm.warp(2);
        _setPrice(1250 * 1e8);

        _openPosition(BOB, 100 ether, 1, 5_000_000);
        vm.warp(3);
        _setPrice(1500 * 1e8);

        // 100 * 250% + 100 * 100%
        assertEq(_tradePair_unrealizedPnL(), 350 ether, "unrealizedPnL before");

        _tradePair_syncUnrealizedPnL();

        // 200 + 350
        assertEq(collateralToken.balanceOf(address(tradePair)), 550 ether, "tradePair balance before");

        // 1000 - 350
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 650 ether, "liquidityPool balance before");
    }

    function test_syncedUnrealizedPnL_aboveTotalCollateral() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);

        // Positon is liquidatable
        vm.warp(2);
        _setPrice(800 * 1e8);
        _tradePair_syncUnrealizedPnL();
        assertEq(collateralToken.balanceOf(address(tradePair)), 100 ether, "tradePair balance after");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1000 ether, "liquidityPool balance after");
    }

    function test__syncUnrealizedPnL_fluctuates() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);
        vm.warp(2);
        _setPrice(1200 * 1e8);
        _tradePair_syncUnrealizedPnL();

        assertEq(collateralToken.balanceOf(address(tradePair)), 200 ether, "tradePair balance after price increase");
        assertEq(
            collateralToken.balanceOf(address(liquidityPool)), 900 ether, "liquidityPool balance after price increase"
        );

        vm.warp(3);
        _setPrice(800 * 1e8);

        _tradePair_syncUnrealizedPnL();
        assertEq(collateralToken.balanceOf(address(tradePair)), 100 ether, "tradePair balance after price decrease");
        assertEq(
            collateralToken.balanceOf(address(liquidityPool)), 1000 ether, "liquidityPool balance after price decrease"
        );
    }

    function test_syncUnrealizedPnL_afterLiquidation() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, LONG, _5X);
        _openPosition(BOB, 100 ether, SHORT, _5X);

        vm.warp(2);
        _setPrice(1500 * 1e8);
        // the short should have been liquidated at 1200

        _tradePair_syncUnrealizedPnL();

        assertEq(collateralToken.balanceOf(address(tradePair)), 200 ether, "tradePair balance before");
        assertEq(_tradePair_unrealizedPnL(), 0, "unrealizedPnL before");

        _liquidatePosition(2);

        _tradePair_syncUnrealizedPnL(); // TODO: remove, tradePair should sync unrealizedPnL on liquidation

        // only one position open, 5x * 50% * 100 = 250
        assertEq(_tradePair_unrealizedPnL(), 250 ether, "unrealizedPnL after");
        assertEq(collateralToken.balanceOf(address(tradePair)), 350 ether, "tradePair balance after");

        _closePosition(BOB, 1);

        _tradePair_syncUnrealizedPnL(); // TODO: remove, tradePair should sync unrealizedPnL on liquidation

        assertEq(_tradePair_unrealizedPnL(), 0 ether, "unrealizedPnL after");
        assertEq(collateralToken.balanceOf(address(tradePair)), 0 ether, "tradePair balance after");
    }

    function test_syncUnrealizedPnL_afterPositionActions() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, LONG, _5X);
        _openPosition(BOB, 100 ether, SHORT, _5X);

        vm.warp(2);
        _setPrice(1500 * 1e8);

        _liquidatePosition(2);

        // only one position open, 5x * 50% * 100 = 250
        assertEq(_tradePair_unrealizedPnL(), 250 ether, "unrealizedPnL after");
        assertEq(collateralToken.balanceOf(address(tradePair)), 350 ether, "tradePair balance after");

        _closePosition(BOB, 1);

        assertEq(_tradePair_unrealizedPnL(), 0 ether, "unrealizedPnL after");
        assertEq(collateralToken.balanceOf(address(tradePair)), 0 ether, "tradePair balance after");
    }

    function test_syncedUnrealizedPnL_afterPositionOpen() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, LONG, _5X);

        vm.warp(2);
        _setPrice(2000 * 1e8);
        assertEq(_tradePair_unrealizedPnL(), 500 ether, "unrealizedPnL before");

        _openPosition(BOB, 100 ether, LONG, _5X);

        // only one position open, 5x * 100% * 100 = 500
        assertEq(_tradePair_unrealizedPnL(), 500 ether, "unrealizedPnL after");
        assertEq(collateralToken.balanceOf(address(tradePair)), 700 ether, "tradePair balance after");
    }

    function test_openPosition_minLeverage() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        deal(address(collateralToken), BOB, 100 ether);

        deal(BOB, 1);
        vm.startPrank(BOB);
        collateralToken.approve(address(tradePair), 100 ether);
        bytes[] memory updateDataArray = _getPythUpdateArrayWithCurrentPrice();
        vm.expectRevert("TradePair::openPosition: Leverage too low");
        tradePair.openPosition{value: 1}(100 ether, 999_999, LONG, updateDataArray);
    }

    function test_openPosition_maxLeverage() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        deal(address(collateralToken), BOB, 100 ether);

        deal(BOB, 1);
        vm.startPrank(BOB);
        collateralToken.approve(address(tradePair), 100 ether);
        bytes[] memory updateDataArray = _getPythUpdateArrayWithCurrentPrice();
        vm.expectRevert("TradePair::openPosition: Leverage too high");
        tradePair.openPosition{value: 1}(100 ether, 100_000_001, LONG, updateDataArray);
    }

    function test_openPosition_invalidDirection() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        deal(address(collateralToken), BOB, 100 ether);

        deal(BOB, 1);
        vm.startPrank(BOB);
        collateralToken.approve(address(tradePair), 100 ether);
        bytes[] memory updateDataArray = _getPythUpdateArrayWithCurrentPrice();
        vm.expectRevert("TradePair::openPosition: Invalid direction");
        tradePair.openPosition{value: 1}(100 ether, _5X, 0, updateDataArray);

        vm.expectRevert("TradePair::openPosition: Invalid direction");
        tradePair.openPosition{value: 1}(100 ether, _5X, 2, updateDataArray);

        vm.expectRevert("TradePair::openPosition: Invalid direction");
        tradePair.openPosition{value: 1}(100 ether, _5X, -2, updateDataArray);
    }

    function test_closePosition_notOwner() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, LONG, _5X);

        deal(ALICE, 1 ether);
        vm.startPrank(ALICE);
        bytes[] memory updateDataArray = _getPythUpdateArrayWithCurrentPrice();
        vm.expectRevert("TradePair::closePosition: Only the owner can close the position");
        tradePair.closePosition{value: 1}(1, updateDataArray);
    }

    function test_closePosition_liquidatable() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, LONG, _5X);

        vm.warp(2);
        _setPrice(800 * 1e8);

        deal(BOB, 1 ether);
        vm.startPrank(BOB);
        bytes[] memory updateDataArray = _getPythUpdateArrayWithCurrentPrice();
        vm.expectRevert("TradePair::closePosition: Position is liquidatable and can not be closed");
        tradePair.closePosition{value: 1}(1, updateDataArray);
    }

    function test_liquidatePosition_doesNotExist() public {
        _setPrice(1000 * 1e8);
        deal(BOB, 1);
        vm.startPrank(BOB);
        bytes[] memory updateDataArray = _getPythUpdateArrayWithCurrentPrice();
        vm.expectRevert("TradePair::liquidatePosition: Position does not exist");
        tradePair.liquidatePosition{value: 1}(1, updateDataArray);
    }

    function test_liquidatePosition_notLiquidatable() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, LONG, _5X);

        vm.warp(2);
        _setPrice(1200 * 1e8);

        deal(BOB, 1);
        vm.startPrank(BOB);
        bytes[] memory updateDataArray = _getPythUpdateArrayWithCurrentPrice();
        vm.expectRevert("TradePair::liquidatePosition: Position is not liquidatable");
        tradePair.liquidatePosition{value: 1}(1, updateDataArray);
    }

    function test_getPositionDetails_doesNotExit() public {
        _setPrice(1000 * 1e8);
        deal(BOB, 1);
        vm.startPrank(BOB);
        vm.expectRevert("TradePair::getPositionDetails: Position does not exist");
        tradePair.getPositionDetails(1, 1000 ether);
    }

    function test_setting_setMaxPriceAge() public {
        _tradePair_setMaxPriceAge(10);
        assertEq(tradePair.maxPriceAge(), 10, "max price age");
    }

    function test_setting_setMaxPriceAge_onlyOwner() public {
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        _tradePair_setMaxPriceAge(10);
    }

    function test_emitsContstructed() public {
        vm.expectEmit();
        emit TradePairConstructed(address(collateralToken), address(mockPyth), 18, 6, PYTH_IOTA_USD, "IOTAUSD");
        tradePair = new TradePair(controller, liquidityPool, 18, 6, address(mockPyth), PYTH_IOTA_USD, "IOTAUSD");
    }
}
