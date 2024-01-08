// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "test/setup/MockPriceFeed.sol";
import "test/setup/constants.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract Simulation is Test {
    TradePair tradePair;
    MockPriceFeed priceFeed;
    ERC20 collateralToken;
    LiquidityPool liquidityPool;

    function setUp() public {
        collateralToken = new ERC20("Collateral", "COLL");
        priceFeed = new MockPriceFeed();
        tradePair = new TradePair(collateralToken, priceFeed);
        liquidityPool = new LiquidityPool(collateralToken, tradePair);
    }

    function test_deposit() public {
        _deposit(ALICE, 1000 ether);
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1000 ether);
        assertEq(liquidityPool.balanceOf(ALICE), 1000 ether);
        _printStats();
    }

    function _deposit(address trader, uint256 amount) internal {
        deal(address(collateralToken), trader, amount);
        vm.startPrank(trader);
        collateralToken.approve(address(liquidityPool), amount);
        liquidityPool.deposit(amount);
        vm.stopPrank();
    }

    function _printStats() internal {
        emit log_named_decimal_uint("alice collateral balance", collateralToken.balanceOf(ALICE), 18);
        emit log_named_decimal_uint("alice lp balance", liquidityPool.balanceOf(ALICE), 18);
        emit log_named_decimal_uint("lp assets", collateralToken.balanceOf(address(liquidityPool)), 18);
        emit log_named_decimal_uint("lp total supply", liquidityPool.totalSupply(), 18);
    }
}
