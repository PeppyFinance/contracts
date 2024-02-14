// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "src/Controller.sol";
import "test/setup/MockPriceFeed.sol";
import "test/setup/constants.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract DeployPeppy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Controller controller = new Controller();
        ERC20 collateralToken = new ERC20("Collateral", "COLL");
        MockPriceFeed priceFeed = new MockPriceFeed();
        LiquidityPool liquidityPool = new LiquidityPool(controller, collateralToken);
        TradePair tradePair = new TradePair(controller, collateralToken, priceFeed, liquidityPool, 18);
        controller.addTradePair(address(tradePair));

        vm.stopBroadcast();
    }
}
