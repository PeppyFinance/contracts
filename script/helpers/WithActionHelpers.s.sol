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
    TradePair tradePairIotaUsd;
    TradePair tradePairEthUsd;
    TradePair tradePairBtcUsd;
    MockPyth mockPyth;
    IERC20Metadata collateralToken;
    LiquidityPool liquidityPool;

    /// @dev deploys contracts to the testnet and deploys mock price feed and tokens
    function deployTestnet() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");

        vm.startBroadcast(deployerPrivateKey);

        controller = new Controller();
        collateralToken = new PeppyUsdc("Collateral", "COLL", MAX_MINTABLE, INITIAL_MINT);
        mockPyth = new MockPyth(10, 1);
        liquidityPool = new LiquidityPool(controller, collateralToken);

        collateralToken.approve(address(liquidityPool), INITIAL_MINT);
        liquidityPool.deposit(INITIAL_MINT);

        tradePairIotaUsd =
            new TradePair(controller, liquidityPool, 18, 18, address(mockPyth), PYTH_IOTA_USD, "IOTA/USD");
        tradePairEthUsd = new TradePair(controller, liquidityPool, 18, 18, address(mockPyth), PYTH_ETH_USD, "ETH/USD");
        tradePairBtcUsd = new TradePair(controller, liquidityPool, 18, 18, address(mockPyth), PYTH_BTC_USD, "BTC/USD");

        controller.addTradePair(address(tradePairIotaUsd));
        controller.addTradePair(address(tradePairEthUsd));
        controller.addTradePair(address(tradePairBtcUsd));

        liquidityPool.setMinBorrowRate(MIN_BORROW_RATE);
        liquidityPool.setMaxBorrowRate(MAX_BORROW_RATE);
        tradePairIotaUsd.setMaxFundingRate(MAX_FUNDING_RATE);
        tradePairEthUsd.setMaxFundingRate(MAX_FUNDING_RATE);
        tradePairBtcUsd.setMaxFundingRate(MAX_FUNDING_RATE);

        vm.stopBroadcast();

        _startJson();
        _writeJson("liquidityPool", address(liquidityPool));
        _writeJson("tradePairIotaUsd", address(tradePairIotaUsd));
        _writeJson("tradePairEthUsd", address(tradePairEthUsd));
        _writeJson("tradePairBtcUsd", address(tradePairBtcUsd));
        _writeJson("collateralToken", address(collateralToken));
        _writeJson("pyth", address(mockPyth));
        _writeJson("controller", address(controller));

        string memory addressFile = string.concat("deployments/", _network, "_addresses.ts");

        // multiple parts of string cocatenation to avoid stack too deep error:

        string memory part1 = string(
            abi.encodePacked(
                "export const controllerAddress = \"",
                vm.toString(address(controller)),
                "\";\n",
                "export const tradePairIotaUsdAddress = \"",
                vm.toString(address(tradePairIotaUsd)),
                "\";\n"
            )
        );

        string memory part2 = string(
            abi.encodePacked(
                "export const tradePairEthUsdAddress = \"",
                vm.toString(address(tradePairEthUsd)),
                "\";\n",
                "export const tradePairBtcUsdAddress = \"",
                vm.toString(address(tradePairBtcUsd)),
                "\";\n"
            )
        );

        string memory part3 = string(
            abi.encodePacked(
                "export const liquidityPoolAddress = \"",
                vm.toString(address(liquidityPool)),
                "\";\n",
                "export const collateralTokenAddress = \"",
                vm.toString(address(collateralToken)),
                "\";\n"
            )
        );

        string memory part4 =
            string(abi.encodePacked("export const pythAddress = \"", vm.toString(address(mockPyth)), "\";\n"));

        string memory addresses = string(abi.encodePacked(part1, part2, part3, part4));
        vm.writeFile(addressFile, addresses);
    }

    /// @dev deploys contracts to the testnet and
    function deployTestnetRealPyth() public {
        uint256 deployerPrivateKey = vm.envUint("PEPPY_DEPLOYER_PK");

        vm.startBroadcast(deployerPrivateKey);

        controller = new Controller();
        collateralToken = new PeppyUsdc("Collateral", "COLL", MAX_MINTABLE, INITIAL_MINT);

        IPyth pyth = IPyth(PYTH_SHIMMER_TESTNET);

        liquidityPool = new LiquidityPool(controller, collateralToken);

        collateralToken.approve(address(liquidityPool), INITIAL_MINT);
        liquidityPool.deposit(INITIAL_MINT);

        tradePairIotaUsd = new TradePair(controller, liquidityPool, 18, 18, address(pyth), PYTH_IOTA_USD, "IOTA/USD");
        tradePairEthUsd = new TradePair(controller, liquidityPool, 18, 18, address(pyth), PYTH_ETH_USD, "ETH/USD");
        tradePairBtcUsd = new TradePair(controller, liquidityPool, 18, 18, address(pyth), PYTH_BTC_USD, "BTC/USD");

        controller.addTradePair(address(tradePairIotaUsd));
        controller.addTradePair(address(tradePairEthUsd));
        controller.addTradePair(address(tradePairBtcUsd));

        liquidityPool.setMinBorrowRate(MIN_BORROW_RATE);
        liquidityPool.setMaxBorrowRate(MAX_BORROW_RATE);
        tradePairIotaUsd.setMaxFundingRate(MAX_FUNDING_RATE);
        tradePairEthUsd.setMaxFundingRate(MAX_FUNDING_RATE);
        tradePairBtcUsd.setMaxFundingRate(MAX_FUNDING_RATE);

        vm.stopBroadcast();

        _startJson();
        _writeJson("liquidityPool", address(liquidityPool));
        _writeJson("tradePairIotaUsd", address(tradePairIotaUsd));
        _writeJson("tradePairEthUsd", address(tradePairEthUsd));
        _writeJson("tradePairBtcUsd", address(tradePairBtcUsd));
        _writeJson("collateralToken", address(collateralToken));
        _writeJson("pyth", address(pyth));
        _writeJson("controller", address(controller));

        string memory addressFile = string.concat("deployments/", _network, "_addresses.ts");

        // multiple parts of string cocatenation to avoid stack too deep error:

        string memory part1 = string(
            abi.encodePacked(
                "export const controllerAddress = \"",
                vm.toString(address(controller)),
                "\";\n",
                "export const tradePairIotaUsdAddress = \"",
                vm.toString(address(tradePairIotaUsd)),
                "\";\n"
            )
        );

        string memory part2 = string(
            abi.encodePacked(
                "export const tradePairEthUsdAddress = \"",
                vm.toString(address(tradePairEthUsd)),
                "\";\n",
                "export const tradePairBtcUsdAddress = \"",
                vm.toString(address(tradePairBtcUsd)),
                "\";\n"
            )
        );

        string memory part3 = string(
            abi.encodePacked(
                "export const liquidityPoolAddress = \"",
                vm.toString(address(liquidityPool)),
                "\";\n",
                "export const collateralTokenAddress = \"",
                vm.toString(address(collateralToken)),
                "\";\n"
            )
        );

        string memory part4 =
            string(abi.encodePacked("export const pythAddress = \"", vm.toString(address(mockPyth)), "\";\n"));

        string memory addresses = string(abi.encodePacked(part1, part2, part3, part4));
        vm.writeFile(addressFile, addresses);
    }

    function testMock_WithActionHelpers() public {}
}
