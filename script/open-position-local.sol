// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "src/Controller.sol";
import "test/setup/MockPriceFeed.sol";
import "test/setup/constants.sol";
import "src/auxiliary/FaucetToken.sol";
import "script/WithDeploymentHelpers.s.sol";
import "forge-std/Vm.sol";

/**
 * @dev Distributes tokens and sets up positions
 */
contract SetupLocalScript is Script, WithDeploymentHelpers {
    function run() external {
        setNetwork("local");

        FaucetToken collateralToken = FaucetToken(_getAddress("collateralToken"));
        TradePair tradePair = TradePair(_getAddress("tradePair"));

        vm.startBroadcast(vm.envUint("ALICE_PK"));
        collateralToken.mint(1_000_000 * 1e18);
        collateralToken.approve(address(tradePair), 1_000_000 * 1e18);
        tradePair.openPosition(1_000 * 1e18, 1_000_000, LONG, new bytes[](0));
        vm.stopBroadcast();
    }
}
