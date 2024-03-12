// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "script/Deploy.s.sol";
import "forge-std/Script.sol";
import "script/WithDeploymentHelpers.s.sol";
import "src/auxiliary/FaucetToken.sol";
import "pyth-sdk-solidity/MockPyth.sol";

contract DeployLocal is Script, WithDeploymentHelpers {
    IPyth pyth;
    IERC20Metadata collateralToken;

    function testMock() public {}

    function run() public {
        string memory _network = "local";
        setNetwork(_network);

        _deployEcosystem();

        DeployPeppy deployScript = new DeployPeppy();
        deployScript.setNetwork(_network);
        deployScript.run();

        _configureLocal();
    }

    function _deployEcosystem() private {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy USDC (an ERC20 token) and MockPyth and set the addresses to the constants
        collateralToken = new FaucetToken("Collateral", "USDC");
        pyth = new MockPyth(10, 1);

        // Set the addresses to the constants
        _writeJson("COLLATERAL", address(collateralToken), _constantsPath);
        _writeJson("PYTH", address(pyth), _constantsPath);

        vm.stopBroadcast();
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
