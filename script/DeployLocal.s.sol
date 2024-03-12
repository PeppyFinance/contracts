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
}
