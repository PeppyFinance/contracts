// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "script/helpers/WithFileHelpers.s.sol";
import "script/Deploy.s.sol";
import "test/setup/constants.sol";
import "src/auxiliary/FaucetToken.sol";
import "pyth-sdk-solidity/MockPyth.sol";

contract WithDeployment is WithFileHelpers, Test {
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
        vm.etch(_getConstant("PYTH"), address(new MockPyth(10, 1)).code);
    }
}
