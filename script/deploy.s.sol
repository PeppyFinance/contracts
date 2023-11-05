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

        FaucetToken collateralToken = new FaucetToken("fUSDC", "fUSDC");

        PriceFeed priceFeed = new PriceFeed(pythAddr);

        priceFeed.setPriceFeed("BTC", 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43);
        priceFeed.setPriceFeed("ETH", 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace);
        priceFeed.setPriceFeed("SMR", 0xaf5b9ac426ae79591fde6816bc3f043b5e06d5e442f52112f76249320df22449);
        priceFeed.setPriceFeed("IOTA", 0xc7b72e5d860034288c9335d4d325da4272fe50c92ab72249d58f6cbba30e4c44);
        priceFeed.setPriceFeed("EUR", 0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b);

        ITradePair tradePair = new TradePair(priceFeed);
        ILiquidityPool liquidityPool = new LiquidityPool(collateralToken);

        tradePair.setLiquidityPool(liquidityPool);
        liquidityPool.setTradePair(tradePair);

        vm.stopBroadcast();
    }
}
