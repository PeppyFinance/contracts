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

contract FeesTest is Test, WithHelpers {
    function setUp() public {
        _deployTestSetup();
    }

    function test_borrowRate_zero() public {
        _deposit(ALICE, 1000 ether);
        assertEq(_tradePair_getBorrowRate(), 0);
    }
}
