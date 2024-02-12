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

contract ControllerTest is Test, WithHelpers {
    function setUp() public {
        _deployTestSetup();
    }

    function test_addTradePair() public {
        controller.addTradePair(address(tradePair));
        assert(controller.isTradePair(address(tradePair)));
    }

    function test_addLiquidityPool() public {
        controller.addLiquidityPool(address(liquidityPool));
        assert(controller.isLiquidityPool(address(liquidityPool)));
    }

    function test_removeTradePair() public {
        controller.addTradePair(address(tradePair));
        controller.removeTradePair(address(tradePair));
        assert(!controller.isTradePair(address(tradePair)));
    }

    function test_removeLiquidityPool() public {
        controller.addLiquidityPool(address(liquidityPool));
        controller.removeLiquidityPool(address(liquidityPool));
        assert(!controller.isLiquidityPool(address(liquidityPool)));
    }
}
