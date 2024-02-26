// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "test/setup/WithDeployment.t.sol";

contract DeploymentTest is WithDeployment {
    function setUp() public {
        setNetwork("DeploymentTest");
        deploy();
    }

    function test_tradePair_deployed() public {
        assertEq(
            address(ITradePair(_getAddress("tradePair")).collateralToken()),
            _getConstant("COLLATERAL"),
            "tradePair.collateralToken should be COLLATERAL"
        );
    }

    function test_liquidityPool_deployed() public {
        assertEq(
            address(ILiquidityPool(_getAddress("liquidityPool")).asset()),
            _getConstant("COLLATERAL"),
            "liquidityPool.asset should be COLLATERAL"
        );
    }
}
