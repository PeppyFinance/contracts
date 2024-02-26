// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "script/WithDeploymentHelpers.s.sol";

import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "src/Controller.sol";
import "test/setup/MockPriceFeed.sol";
import "test/setup/constants.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "forge-std/Vm.sol";
import "src/auxiliary/FaucetToken.sol";

contract DeployPeppy is Script, WithDeploymentHelpers {
    Controller controller;
    TradePair tradePair;
    MockPriceFeed priceFeed;
    IERC20Metadata collateralToken;
    LiquidityPool liquidityPool;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        _startJson();

        vm.startBroadcast(deployerPrivateKey);

        _setCollateralToken();

        controller = new Controller();
        priceFeed = new MockPriceFeed();
        liquidityPool = new LiquidityPool(controller, collateralToken);
        tradePair = new TradePair(controller, collateralToken, priceFeed, liquidityPool, 18);
        controller.addTradePair(address(tradePair));

        vm.stopBroadcast();

        _writeJson("liquidityPool", address(liquidityPool));
        _writeJson("tradePair", address(tradePair));
        _writeJson("collateralToken", address(collateralToken));
        _writeJson("priceFeed", address(priceFeed));
        _writeJson("controller", address(controller));

        string memory addressFile = string.concat("deploy/addresses_", _network, ".ts");

        string memory addresses = string(
            abi.encodePacked(
                "export const controllerAddress = \"",
                vm.toString(address(controller)),
                "\";\n",
                "export const tradePairAddress = \"",
                vm.toString(address(tradePair)),
                "\";\n",
                "export const liquidityPoolAddress = \"",
                vm.toString(address(liquidityPool)),
                "\";\n",
                "export const collateralTokenAddress = \"",
                vm.toString(address(collateralToken)),
                "\";\n",
                "export const priceFeedAddress = \"",
                vm.toString(address(priceFeed)),
                "\";\n"
            )
        );
        vm.writeFile(addressFile, addresses);
    }

    function _setCollateralToken() private {
        collateralToken = IERC20Metadata(_getConstant("COLLATERAL"));

        // write to json to know which usdc is used for the deployment
        _writeJson("usdc", address(collateralToken));
    }
}
