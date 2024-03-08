// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "test/setup/WithDeployment.t.sol";
import "pyth-sdk-solidity/IPyth.sol";
import "pyth-sdk-solidity/MockPyth.sol";

contract DeploymentTest is WithDeployment {
    function setUp() public {
        setNetwork("DeploymentTest");
        deploy();
    }

    function test_tradePair_deployed() public {
        assertEq(
            address(ITradePair(_getAddress("tradePair")).collateralToken()),
            _getAddress("collateralToken"),
            "tradePair.collateralToken should be COLLATERAL"
        );
    }

    function test_liquidityPool_deployed() public {
        assertEq(
            address(ILiquidityPool(_getAddress("liquidityPool")).asset()),
            _getAddress("collateralToken"),
            "liquidityPool.asset should be COLLATERAL"
        );
    }

    function test_pythPriceFeed() public {
        bytes32 id = bytes32("btc");
        IPyth pyth = IPyth(_getConstant("PYTH"));
        bytes memory updateData =
            MockPyth(address(pyth)).createPriceFeedUpdateData(id, 123, 456, 789, 120, 400, uint64(block.timestamp));
        bytes[] memory updateDataArray = new bytes[](1);
        updateDataArray[0] = updateData;
        pyth.updatePriceFeeds{value: 1}(updateDataArray);
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(id, 0);
        assertEq(price.price, 123, "Price should be 123");
        assertEq(price.conf, 456, "Price should be 456");
    }
}
