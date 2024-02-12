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
    }

    function test_pnl_profit_short() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(address(collateralToken), 1000 ether);

        _openPosition(BOB, 100 ether, SHORT, _5X);

        _setPrice(address(collateralToken), 800 ether);
        _closePosition(BOB, 1);

        assertEq(collateralToken.balanceOf(BOB), 200 ether, "should have made 100% profit");
    }
}
