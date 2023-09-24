#!/bin/bash

# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/deploy.s.sol:Deploy --rpc-url $SHIMMER_RPC_URL --broadcast --verify -vvvv
