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

contract OpenCloseFeeTest is Test, WithHelpers {
    function setUp() public {
        _deployTestSetup();
    }

    function test_openFee_zero() public {
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);

        assertEq(
            collateralToken.balanceOf(address(liquidityPool)), 1000 ether, "liquidityPool did not receive open fee"
        );
    }

    function test_setting_setOpenFee() public {
        _tradePair_setOpenFee(10 * BPS);
        assertEq(tradePair.openFee(), 10 * BPS, "open fee");
    }

    function test_setting_setCloseFee() public {
        _tradePair_setCloseFee(10 * BPS);
        assertEq(tradePair.closeFee(), 10 * BPS, "close fee");
    }

    function test_openFee_transferedToLp() public {
        _tradePair_setOpenFee(10 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);

        assertEq(
            collateralToken.balanceOf(address(liquidityPool)),
            1000 ether + 100 ether * 10 * 5 / 10_000,
            "liquidityPool did not receive open fee"
        );
    }

    function test_closeFee_transferedToLp() public {
        _tradePair_setCloseFee(10 * BPS);
        _deposit(ALICE, 1000 ether);
        _setPrice(1000 * 1e8);
        _openPosition(BOB, 100 ether, 1, 5_000_000);

        _setPrice(1000 * 1e8);
        _closePosition(BOB, 1);

        assertEq(
            collateralToken.balanceOf(address(liquidityPool)),
            1000 ether + 100 ether * 10 / 10_000,
            "liquidityPool did not receive close fee"
        );
    }
}
