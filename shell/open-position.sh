#!/bin/bash

# To load the variables in the .env file
source .env

# Open position
forge script script/SetupLocal.s.sol --fork-url http://localhost:8545 --broadcast --verify -vvvv --legacy
