#!/bin/bash

# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/setup-local.s.sol --fork-url http://localhost:8545 --broadcast --verify -vvvv --legacy
