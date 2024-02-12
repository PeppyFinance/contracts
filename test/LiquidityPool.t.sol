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

    function test_previewRedeem_noSupply() public {
        assertEq(liquidityPool.previewRedeem(1), 0);
    }

    function test_redeem_noBalance() public {
        vm.startPrank(ALICE);
        vm.expectRevert("LiquidityPool::redeem: Insufficient balance.");
        liquidityPool.redeem(1);
    }

    function test_redeem_zeroShares() public {
        vm.startPrank(ALICE);
        vm.expectRevert("LiquidityPool::redeem: Shares must be greater than 0.");
        liquidityPool.redeem(0);

        // should throw again even if balance is > 0
        _deposit(ALICE, 100 ether);
        vm.expectRevert("LiquidityPool::redeem: Shares must be greater than 0.");
        liquidityPool.redeem(0);
    }
}
