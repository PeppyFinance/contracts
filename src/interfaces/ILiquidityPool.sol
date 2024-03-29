// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

int256 constant BPS = 1e6;

interface ILiquidityPool is IERC20 {
    function redeem(uint256 shares) external;
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function totalAssets() external view returns (uint256);

    function setMinBorrowRate(int256 rate) external;
    function setMaxBorrowRate(int256 rate) external;
    function asset() external view returns (IERC20Metadata);
    function minBorrowRate() external view returns (int256);
    function maxBorrowRate() external view returns (int256);
    function ratio() external view returns (uint256);
    function requestPayout(uint256) external;
    function getBorrowRate(int256) external view returns (int256);

    event Deposit(address indexed sender, uint256 assets, uint256 shares);
    event Redeem(address indexed sender, uint256 assets, uint256 shares);
    event ProtocolSet(address indexed protocol);
    event MinBorrowRateSet(int256 rate);
    event MaxBorrowRateSet(int256 rate);
}
