// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "script/testnet/Deploy.s.sol";
import "script/helpers/WithFileHelpers.s.sol";
import "pyth-sdk-solidity/IPyth.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "test/setup/constants.sol";

contract DeploymentTest is Test, WithFileHelpers {
    function setUp() public {
        setNetwork("testrun");
        TestnetDeployment testnetDeployment = new TestnetDeployment();
        testnetDeployment.run();
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

    function test_tradePair_pricefeed() public {
        assertEq(
            address(ITradePair(_getAddress("tradePair")).pyth()), _getAddress("pyth"), "tradePair.pyth should be pyth"
        );
    }

    function test_pythPriceFeed_success() public {
        bytes32 id = bytes32("btc");
        IPyth pyth = IPyth(_getAddress("pyth"));
        bytes memory updateData =
            MockPyth(address(pyth)).createPriceFeedUpdateData(id, 123, 456, 789, 120, 400, uint64(block.timestamp));
        bytes[] memory updateDataArray = new bytes[](1);
        updateDataArray[0] = updateData;
        pyth.updatePriceFeeds{value: 1}(updateDataArray);
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(id, 0);
        assertEq(price.price, 123, "Price should be 123");
        assertEq(price.conf, 456, "Price should be 456");
    }

    function test_pythPriceFeed_stale() public {
        vm.warp(10);
        bytes32 id = bytes32("btc");
        IPyth pyth = IPyth(_getAddress("pyth"));
        bytes memory updateData = MockPyth(address(pyth)).createPriceFeedUpdateData(id, 123, 456, 789, 120, 400, 8);
        bytes[] memory updateDataArray = new bytes[](1);
        updateDataArray[0] = updateData;
        pyth.updatePriceFeeds{value: 1}(updateDataArray);
        vm.expectRevert(abi.encodeWithSelector(PythErrors.StalePrice.selector));
        pyth.getPriceNoOlderThan(id, 0);
    }

    function test_peppyUsdc_maxMintable() public {
        PeppyUsdc peppyUsdc = PeppyUsdc(_getAddress("collateralToken"));

        vm.startPrank(BOB);
        peppyUsdc.mint(MAX_MINTABLE);

        vm.expectRevert("PeppyUsdc::mint: max mintable exceeded");
        peppyUsdc.mint(MAX_MINTABLE);
    }

    function test_peppyUsdc_initialMint() public {
        PeppyUsdc peppyUsdc = PeppyUsdc(_getAddress("collateralToken"));
        assertEq(peppyUsdc.balanceOf(address(vm.envAddress("DEPLOYER"))), INITIAL_MINT, "Initial mint should be 1000");
    }
}
