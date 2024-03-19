// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "script/testnet/Deploy.s.sol";
import "forge-std/Script.sol";
import "script/helpers/WithFileHelpers.s.sol";
import "src/auxiliary/FaucetToken.sol";
import "pyth-sdk-solidity/MockPyth.sol";

contract DeployLocal is Script, WithFileHelpers {
    IPyth pyth;
    IERC20Metadata collateralToken;

    function testMock() public {}

    function run() public {
        setNetwork(vm.envOr("NETWORK", string("testrun")));

        TestnetDeployment deployScript = new TestnetDeployment();
        deployScript.run();

        _configureLocal();
    }

    function _configureLocal() private {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        ITradePair tradePair = ITradePair(_getAddress("tradePair"));
        // As the local network is out of sync with the real timestamp, max price age has to be high to avoid StalePrice errors
        tradePair.setMaxPriceAge(42 * 365 days);

        vm.stopBroadcast();
    }
}
