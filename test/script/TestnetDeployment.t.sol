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

    function test_tradePairs_deployed() public {
        assertEq(
            address(ITradePair(_getAddress("tradePairIotaUsd")).collateralToken()),
            _getAddress("collateralToken"),
            "tradePairIotaUsd.collateralToken should be COLLATERAL"
        );
        assertEq(
            address(ITradePair(_getAddress("tradePairEthUsd")).collateralToken()),
            _getAddress("collateralToken"),
            "tradePairEthUsd.collateralToken should be COLLATERAL"
        );
        assertEq(
            address(ITradePair(_getAddress("tradePairBtcUsd")).collateralToken()),
            _getAddress("collateralToken"),
            "tradePairBtcUsd.collateralToken should be COLLATERAL"
        );
    }

    function test_liquidityPool_deployed() public {
        assertEq(
            address(ILiquidityPool(_getAddress("liquidityPool")).asset()),
            _getAddress("collateralToken"),
            "liquidityPool.asset should be COLLATERAL"
        );
    }

    function test_controller_tradePairs() public {
        assertTrue(
            IController(_getAddress("controller")).isTradePair(_getAddress("tradePairIotaUsd")),
            "tradePairIotaUsd should be in controller"
        );
        assertTrue(
            IController(_getAddress("controller")).isTradePair(_getAddress("tradePairEthUsd")),
            "tradePairEthUsd should be in controller"
        );
        assertTrue(
            IController(_getAddress("controller")).isTradePair(_getAddress("tradePairBtcUsd")),
            "tradePairBtcUsd should be in controller"
        );
    }

    function test_tradePairs_pricefeed() public {
        assertEq(
            address(ITradePair(_getAddress("tradePairIotaUsd")).pyth()),
            _getAddress("pyth"),
            "tradePairIotaUsd.pyth should be pyth"
        );
        assertEq(
            address(ITradePair(_getAddress("tradePairEthUsd")).pyth()),
            _getAddress("pyth"),
            "tradePairEthUsd.pyth should be pyth"
        );
        assertEq(
            address(ITradePair(_getAddress("tradePairBtcUsd")).pyth()),
            _getAddress("pyth"),
            "tradePairBtcUsd.pyth should be pyth"
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

    function test_liquidityPool_initialDeposit() public {
        ILiquidityPool liquidityPool = ILiquidityPool(_getAddress("liquidityPool"));
        assertEq(liquidityPool.balanceOf(address(vm.envAddress("DEPLOYER"))), INITIAL_MINT, "Initial deposit");
    }

    function test_liquidityPool_borrowRates() public {
        ILiquidityPool liquidityPool = ILiquidityPool(_getAddress("liquidityPool"));
        assertEq(liquidityPool.minBorrowRate(), MIN_BORROW_RATE, "minBorrowRate should be 0.005");
        assertEq(liquidityPool.maxBorrowRate(), MAX_BORROW_RATE, "maxBorrowRate should be 0.05");
    }

    function test_tradePairs_fundingRate() public {
        ITradePair tradePairIotaUsd = ITradePair(_getAddress("tradePairIotaUsd"));
        assertEq(tradePairIotaUsd.maxFundingRate(), MAX_FUNDING_RATE, "maxFundingRate should be 0.05");

        ITradePair tradePairEthUsd = ITradePair(_getAddress("tradePairEthUsd"));
        assertEq(tradePairEthUsd.maxFundingRate(), MAX_FUNDING_RATE, "maxFundingRate should be 0.05");

        ITradePair tradePairBtcUsd = ITradePair(_getAddress("tradePairBtcUsd"));
        assertEq(tradePairBtcUsd.maxFundingRate(), MAX_FUNDING_RATE, "maxFundingRate should be 0.05");
    }
}
