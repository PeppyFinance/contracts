// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "../src/LiquidityPool.sol";
import "../src/PriceFeed.sol";
import "../src/TradePair.sol";
import "../src/FaucetToken.sol";

contract Deploy is Script {
    function run() external {
        // TODO: probably best to use different method without revealing priv key :D
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address pythAddr = vm.envAddress("PYTH_ADDR");

        FaucetToken collateralToken = new FaucetToken("fake EUR", "fakeEUR");
        // NOTE: not really used, only for its address as a key
        FaucetToken _asset = new FaucetToken("fake ETH", "fakeETH");

        PriceFeed priceFeed = new PriceFeed(pythAddr);
        LiquidityPool liquidityPool = new LiquidityPool(_asset);
        new TradePair(collateralToken, priceFeed, liquidityPool);

        // TODO: print addresses

        vm.stopBroadcast();
    }
}
