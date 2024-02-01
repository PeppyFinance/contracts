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
}
