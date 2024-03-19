#!/bin/bash

# To load the variables in the .env file
source .env

# To deploy and verify our contract
NETWORK=testnet forge script script/testnet/DeployRealPyth.s.sol --fork-url https://json-rpc.evm.testnet.shimmer.network -vvvv --legacy
