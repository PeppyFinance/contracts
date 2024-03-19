#!/bin/bash

# To load the variables in the .env file
source .env

# To deploy and verify our contract
NETWORK=local forge script script/DeployLocal.s.sol --fork-url http://localhost:8545 --broadcast -vvvv --legacy
NETWORK=local forge script script/SetupLocal.s.sol --fork-url http://localhost:8545 --broadcast -vvvv --legacy
