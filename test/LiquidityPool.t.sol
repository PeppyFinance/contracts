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

contract LiquidityPoolTest is Test, WithHelpers {
    function setUp() public {
        _deployTestSetup();
    }

    function test_deposit_invalidAmount() public {
        vm.startPrank(ALICE);
        vm.expectRevert("LiquidityPool::deposit: Amount must be greater than 0");
        liquidityPool.deposit(0);
    }
}
