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

contract Simulation is Test, WithHelpers {
    function setUp() public {
        deployTestSetup();
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
        assertEq(collateralToken.balanceOf(address(tradePair)), 100 ether, "traderPair assets");
        assertEq(liquidityPool.balanceOf(ALICE), 1000 ether, "alice lp balance");
        assertEq(tradePair.longOpenInterest(), 500 ether, "long open interest");
        assertEq(tradePair.shortOpenInterest(), 0 ether, "short open interest");
    }

    function test_closePosition_profit() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);

        // increase price by 10%
        _setPrice(address(collateralToken), 1100 ether);
        _closePosition(BOB, 1);

        // Bob should have made 50 profit
        assertEq(collateralToken.balanceOf(BOB), 150 ether, "bob collateral balance");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 950 ether, "lp assets");
        assertEq(collateralToken.balanceOf(address(tradePair)), 0, "traderPair assets");
        assertEq(liquidityPool.balanceOf(ALICE), 1000 ether, "alice lp balance");
        assertEq(liquidityPool.previewRedeem(1000 ether), 950 ether, "alice redeemable");
        assertEq(tradePair.longOpenInterest(), 0 ether, "long open interest");
        assertEq(tradePair.shortOpenInterest(), 0 ether, "short open interest");
    }

    function test_closePosition_Loss() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);

        // decrease price by 10%
        _setPrice(address(collateralToken), 900 ether);
        _closePosition(BOB, 1);

        // Bob should have lost 50
        assertEq(collateralToken.balanceOf(BOB), 50 ether, "bob collateral balance");
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1050 ether, "lp assets");
        assertEq(collateralToken.balanceOf(address(tradePair)), 0, "traderPair assets");
        assertEq(liquidityPool.balanceOf(ALICE), 1000 ether, "alice lp balance");
        assertEq(liquidityPool.previewRedeem(1000 ether), 1050 ether, "alice redeemable");
        assertEq(tradePair.longOpenInterest(), 0 ether, "long open interest");
        assertEq(tradePair.shortOpenInterest(), 0 ether, "short open interest");
    }

    function test_closePosition_Liquidation() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);

        // decrease price by 50%
        _setPrice(address(collateralToken), 500 ether);
        _liquidatePosition(1);

        // Bob should have lost everything
        assertEq(collateralToken.balanceOf(BOB), 0 ether, "bob collateral balance");
        assertEq(
            collateralToken.balanceOf(address(liquidityPool)), 1100 ether - tradePair.liquidatorReward(), "lp assets"
        );
        assertEq(collateralToken.balanceOf(address(tradePair)), 0, "traderPair assets");
        assertEq(collateralToken.balanceOf(address(this)), tradePair.liquidatorReward(), "traderPair assets");
        assertEq(liquidityPool.balanceOf(ALICE), 1000 ether, "alice lp balance");
        assertEq(liquidityPool.previewRedeem(1000 ether), 1100 ether - tradePair.liquidatorReward(), "alice redeemable");
        assertEq(tradePair.longOpenInterest(), 0 ether, "long open interest");
        assertEq(tradePair.shortOpenInterest(), 0 ether, "short open interest");
    }

    function test_frontrun_traderLoss() public {
        _logState("before");

        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);
        _openPosition(BOB, 100 ether, 1, 5_000_000);

        _logState("after");

        // Now bobs position is nearly liquidatable
        _setPrice(address(collateralToken), 801 ether);
        // Alice's shares are still worth 1000 ether
        assertEq(liquidityPool.previewRedeem(1000 ether), 1000 ether, "alice redeemable");
        // Dan frontruns
        _deposit(DAN, 1000 ether);
        // position gets liquidated
        _setPrice(address(collateralToken), 800 ether);
        _liquidatePosition(1);
        // Dan withdraws
        _redeem(DAN, 1000 ether);
        // Dan made a fast profit
        assertEq(collateralToken.balanceOf(DAN), 1049.5 ether, "dan collateral balance");
        // Alice only got half of the profit
        assertEq(liquidityPool.previewRedeem(1000 ether), 1049.5 ether, "alice redeemable");
    }

    function test_frontrun_traderProfit() public {
        _logState("before deposit");

        _deposit(ALICE, 1000 ether);
        _deposit(DAN, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _logState("after deposit");

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        _logState("after position open");

        // Now bobs position is nearly liquidatable
        _setPrice(address(collateralToken), 1200 ether);
        // Alice's shares are still worth 1000 ether
        assertEq(liquidityPool.previewRedeem(1000 ether), 1000 ether, "alice redeemable");
        // Dan frontruns

        // position gets liquidated
        _setPrice(address(collateralToken), 1200 ether);
        _closePosition(BOB, 1);

        _logState("after position close");

        // Dan withdraws
        _redeem(DAN, 1000 ether);
        // Dan made a fast profit
        assertEq(collateralToken.balanceOf(DAN), 950 ether, "dan collateral balance");
        // Alice only got half of the profit
        assertEq(liquidityPool.previewRedeem(1000 ether), 950 ether, "alice claim");
    }

    function test_frontrun_traderProfit_executed() public {
        _logState("before deposit");

        _deposit(ALICE, 1000 ether);
        _deposit(DAN, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _logState("after deposit");

        _openPosition(BOB, 100 ether, 1, 5_000_000);

        _logState("after position open");

        // Now bobs position is nearly liquidatable
        _setPrice(address(collateralToken), 1200 ether);
        // Alice's shares are still worth 1000 ether
        assertEq(liquidityPool.previewRedeem(1000 ether), 1000 ether, "alice redeemable");
        // Dan frontruns

        // position gets liquidated
        _setPrice(address(collateralToken), 1200 ether);

        // "Frontrunning" occurs:
        _redeem(DAN, 1000 ether);

        _logState("after dan redeem");

        _closePosition(BOB, 1);

        _logState("after position close");

        // Dan withdraws
        // Dan made a fast profit
        assertEq(collateralToken.balanceOf(DAN), 1000 ether, "dan collateral balance");
        // Alice only got half of the profit
        assertEq(liquidityPool.previewRedeem(1000 ether), 900 ether, "alice redeemable");
    }
}
