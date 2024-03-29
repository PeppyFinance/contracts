// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "src/ProductionConstants.sol";

// standard foundry/anvil accounts
address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // (1)
uint256 constant ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // (2)
uint256 constant BOB_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
address constant CATE = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // (3)
uint256 constant CATE_PK = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
address constant DAN = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

int8 constant LONG = 1;
int8 constant SHORT = -1;

// leverages

uint256 constant _1X = 1_000_000;
uint256 constant _2X = 2_000_000;
uint256 constant _3X = 3_000_000;
uint256 constant _4X = 4_000_000;
uint256 constant _5X = 5_000_000;
