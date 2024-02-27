#!/bin/bash

# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/DeployLocal.s.sol --fork-url http://localhost:8545 --broadcast --verify -vvvv --legacy
forge script script/SetupLocal.s.sol --fork-url http://localhost:8545 --broadcast --verify -vvvv --legacy
