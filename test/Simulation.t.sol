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
        deal(address(collateralToken), ALICE, 1000 ether);
        vm.startPrank(ALICE);
        collateralToken.approve(address(liquidityPool), 1000 ether);
        liquidityPool.deposit(1000 ether);
        assertEq(collateralToken.balanceOf(address(liquidityPool)), 1000 ether);
        assertEq(liquidityPool.balanceOf(ALICE), 1000 ether);
    }
}
