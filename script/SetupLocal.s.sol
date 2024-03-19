// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "script/helpers/WithFileHelpers.s.sol";

import "src/TradePair.sol";
import "src/LiquidityPool.sol";
import "src/Controller.sol";
import "pyth-sdk-solidity/MockPyth.sol";
import "test/setup/constants.sol";
import "src/auxiliary/PeppyUsdc.sol";
import "forge-std/Vm.sol";

/**
 * @dev Distributes tokens and sets up positions
 */
contract SetupLocal is Script, WithFileHelpers {
    MockPyth mockPyth;

    function testSetupLocal() public {}

    function run() external {
        setNetwork("local");

        PeppyUsdc collateralToken = PeppyUsdc(_getAddress("collateralToken"));
        TradePair tradePair = TradePair(_getAddress("tradePair"));
        mockPyth = MockPyth(_getAddress("pyth"));

        vm.startBroadcast(vm.envUint("ALICE_PK"));
        collateralToken.mint(1_000_000 * 1e18);
        collateralToken.approve(address(tradePair), 1_000_000 * 1e18);
        bytes[] memory updateDataArray = _getPythUpdateArray(1_000_000_000);
        tradePair.openPosition{value: 1}(1_000 * 1e18, 1_000_000, LONG, updateDataArray);
        vm.stopBroadcast();
    }

    function _getPythUpdateArray(int64 price_) internal view returns (bytes[] memory) {
        bytes memory updateData = MockPyth(address(mockPyth)).createPriceFeedUpdateData(
            PYTH_IOTA_USD, price_, 456, -8, 120, 400, uint64(block.timestamp)
        );

        bytes[] memory updateDataArray = new bytes[](1);
        updateDataArray[0] = updateData;
        return updateDataArray;
    }
}
