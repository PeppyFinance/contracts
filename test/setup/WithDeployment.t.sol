// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "script/WithDeploymentHelpers.s.sol";
import "script/deploy.s.sol";
import "test/setup/constants.sol";
import "src/auxiliary/FaucetToken.sol";

contract WithDeployment is WithDeploymentHelpers, Test {
    function testMock() public virtual {}

    function deploy() public {
        _simulateEcosystem();

        DeployPeppy deployScript = new DeployPeppy();
        deployScript.setNetwork(_network);
        deployScript.run();
    }

    /// @dev Etch contracts outside the protocol
    function _simulateEcosystem() private {
        // Deploy USDC (an ERC20 token) to the collateral address
        vm.etch(_getConstant("COLLATERAL"), address(new FaucetToken("Colletaral", "USDC")).code);
    }
}
