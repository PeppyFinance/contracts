// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "src/interfaces/ILiquidityPool.sol";
import "src/interfaces/ITradePair.sol";

contract LiquidityPool is ERC20, ILiquidityPool {
    using SafeERC20 for IERC20;

    IERC20 public asset;
    int256 public maxBorrowRate; // Hourly
    ITradePair public tradePair;

    uint256 private constant _ASSET_TO_SHARES_MULTIPLIER = 1e12;
    uint256 private constant _PRECISION = 1e6;

    modifier onlyTradePair() {
        require(msg.sender == address(tradePair), "LiquidityPool::onlyTradePair: Invalid trade pair.");
        _;
    }

    constructor(IERC20 asset_, ITradePair tradePair_) ERC20("Perpy Liquidity Pool Token", "PPT") {
        require(address(asset_) != address(0), "LiquidityPool::constructor: Invalid asset address.");
        asset = asset_;
        tradePair = tradePair_;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "LiquidityPool::deposit: Invalid amount.");
        asset.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, previewDeposit(amount));
        _updateFeeIntegrals();
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return (shares * totalAssets()) / totalSupply();
    }

    function requestPayout(uint256 amount) external onlyTradePair {
        asset.safeTransfer(msg.sender, amount);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return (assets > 0 && supply > 0) ? assets * supply / totalAssets() : assets * _ASSET_TO_SHARES_MULTIPLIER;
    }

    function redeem(uint256 shares) external {
        require(balanceOf(msg.sender) >= shares, "LiquidityPool::redeem: Insufficient balance.");

        uint256 assets = previewRedeem(shares);

        _burn(msg.sender, shares);

        emit Redeem(msg.sender, assets, shares);

        asset.safeTransfer(msg.sender, assets);

        _updateFeeIntegrals();
    }

    function setMaxBorrowRate(int256 rate) external {
        maxBorrowRate = rate;
        emit MaxBorrowRateSet(rate);
    }

    function totalAssets() public view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    function ratio() public view returns (uint256) {
        return totalSupply() / totalAssets();
    }

    function _updateFeeIntegrals() internal {
        tradePair.updateFeeIntegrals();
    }
}
