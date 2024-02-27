// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "script/Deploy.s.sol";
import "forge-std/Script.sol";
import "script/WithDeploymentHelpers.s.sol";

contract DeployLocal is Script, WithDeploymentHelpers {
    function testMock() public {}

    function run() public {
        string memory _network = "local";

        DeployPeppy deployScript = new DeployPeppy();
        deployScript.setNetwork(_network);
        deployScript.run();
    }
}
