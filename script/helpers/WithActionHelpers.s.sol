// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "script/helpers/WithFileHelpers.s.sol";
import "src/auxiliary/PeppyUsdc.sol";
import "pyth-sdk-solidity/MockPyth.sol";
import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "src/Controller.sol";
import "src/ProductionConstants.sol";

contract WithActionHelpers is Script, WithFileHelpers {
    Controller controller;
    TradePair tradePair;
    MockPyth mockPyth;
    IERC20Metadata collateralToken;
    LiquidityPool liquidityPool;

    /// @dev deploys contracts to the testnet and deploys mock price feed and tokens
    function deployTestnet() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");

        vm.startBroadcast(deployerPrivateKey);

        controller = new Controller();
        collateralToken = new PeppyUsdc("Collateral", "COLL", MAX_MINTABLE);
        mockPyth = new MockPyth(10, 1);
        liquidityPool = new LiquidityPool(controller, collateralToken);
        tradePair = new TradePair(controller, liquidityPool, 18, 18, address(mockPyth), PYTH_IOTA_USD, "IOTAUSD");
        controller.addTradePair(address(tradePair));

        vm.stopBroadcast();

        _startJson();
        _writeJson("liquidityPool", address(liquidityPool));
        _writeJson("tradePair", address(tradePair));
        _writeJson("collateralToken", address(collateralToken));
        _writeJson("pyth", address(mockPyth));
        _writeJson("controller", address(controller));

        string memory addressFile = string.concat("deployments/", _network, "_addresses.ts");

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
                "export const pythAddress = \"",
                vm.toString(address(mockPyth)),
                "\";\n"
            )
        );
        vm.writeFile(addressFile, addresses);
    }

    function testMock_WithActionHelpers() public {}
}
