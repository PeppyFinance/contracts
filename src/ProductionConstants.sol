// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

// Pyth oracles
bytes32 constant PYTH_IOTA_USD = 0xc7b72e5d860034288c9335d4d325da4272fe50c92ab72249d58f6cbba30e4c44;
bytes32 constant PYTH_ETH_USD = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
bytes32 constant PYTH_BTC_USD = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

uint256 constant MAX_MINTABLE = 100_000 * 1e18;
uint256 constant INITIAL_MINT = 1_000_000 * 1e18;

// TradePair
int256 constant MIN_BORROW_RATE = 5 * 1e2;
int256 constant MAX_BORROW_RATE = 50 * 1e2;
int256 constant MAX_FUNDING_RATE = 50 * 1e2;
