// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "script/Deploy.s.sol";
import "forge-std/Script.sol";
import "script/WithDeploymentHelpers.s.sol";
import "src/auxiliary/FaucetToken.sol";
import "pyth-sdk-solidity/MockPyth.sol";

contract DeployTest is Script, WithDeploymentHelpers {
    function testMock() public {}

    function run() public {
        string memory _network = "test";

        _simulateEcosystem();

        DeployPeppy deployScript = new DeployPeppy();
        deployScript.setNetwork(_network);
        deployScript.run();
    }

    function _simulateEcosystem() private {
        // Deploy USDC (an ERC20 token) to the collateral address
        vm.etch(_getConstant("COLLATERAL"), address(new FaucetToken("Colletaral", "USDC")).code);
        vm.etch(_getConstant("PYTH"), address(new MockPyth(10, 1)).code);
    }
}
