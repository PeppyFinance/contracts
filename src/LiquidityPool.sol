// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "src/interfaces/ILiquidityPool.sol";

contract LiquidityPool is ERC20, ILiquidityPool {
    using SafeERC20 for IERC20;

    IERC20 public asset;
    int256 public maxBorrowRate; // Hourly
    mapping(address => bool) public isTradePair;

    uint256 private constant _ASSET_TO_SHARES_MULTIPLIER = 1e12;
    uint256 private constant _PRECISION = 1e6;

    modifier onlyTradePair() {
        require(isTradePair[msg.sender], "LiquidityPool::onlyTradePair: Invalid trade pair.");
        _;
    }

    constructor(IERC20 asset_) ERC20("Perpy Liquidity Pool Token", "PPT") {
        require(address(asset_) != address(0), "LiquidityPool::constructor: Invalid asset address.");
        asset = asset_;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "LiquidityPool::deposit: Invalid amount.");
        asset.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, previewDeposit(amount));
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return (shares * totalAssets()) / totalSupply();
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
    }

    function addTradePair(address tradePair) external {
        require(tradePair != address(0), "LiquidityPool::addTradePair: Invalid trade pair address.");
        require(!isTradePair[tradePair], "LiquidityPool::addTradePair: Trade pair already added.");
        isTradePair[tradePair] = true;
        emit TradePairAdded(tradePair);
    }

    function removeTradePair(address tradePair) external {
        require(isTradePair[tradePair], "Trade pair not found.");
        isTradePair[tradePair] = false;
        emit TradePairRemoved(tradePair);
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
}
