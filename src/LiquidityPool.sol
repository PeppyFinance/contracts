// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "src/interfaces/ILiquidityPool.sol";
import "src/interfaces/IController.sol";

contract LiquidityPool is ERC20, ILiquidityPool {
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public asset;
    int256 public minBorrowRate; // Hourly in BPS (1e6)
    int256 public maxBorrowRate; // Hourly in BPS (1e6)
    IController public controller;

    uint256 private immutable _ONE_LPT;

    modifier onlyTradePair() {
        require(controller.isTradePair(msg.sender), "LiquidityPool::onlyTradePair: Invalid trade pair.");
        _;
    }

    constructor(IController controller_, IERC20Metadata asset_) ERC20("Peppy Liquidity Pool Token", "PPT") {
        require(address(controller_) != address(0), "LiquidityPool::constructor: Invalid controller address.");
        require(address(asset_) != address(0), "LiquidityPool::constructor: Invalid asset address.");
        controller = controller_;
        asset = asset_;

        _ONE_LPT = 10 ** decimals();
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "LiquidityPool::deposit: Amount must be greater than 0");

        uint256 shares = previewDeposit(amount);

        _mint(msg.sender, shares);

        asset.safeTransferFrom(msg.sender, address(this), amount);

        _updateFeeIntegrals();

        emit Deposit(msg.sender, amount, shares);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        if (totalSupply() == 0) {
            return 0;
        }
        return (shares * totalAssets()) / totalSupply();
    }

    function requestPayout(uint256 amount) external onlyTradePair {
        asset.safeTransfer(msg.sender, amount);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return (assets > 0 && supply > 0)
            ? (assets * supply) / totalAssets()
            : (assets * _ONE_LPT) / (10 ** asset.decimals());
    }

    function redeem(uint256 shares) external {
        require(shares > 0, "LiquidityPool::redeem: Shares must be greater than 0.");
        require(balanceOf(msg.sender) >= shares, "LiquidityPool::redeem: Insufficient balance.");

        uint256 assets = previewRedeem(shares);

        _burn(msg.sender, shares);

        asset.safeTransfer(msg.sender, assets);

        _updateFeeIntegrals();

        emit Redeem(msg.sender, assets, shares);
    }

    function setMaxBorrowRate(int256 rate) external {
        maxBorrowRate = rate;

        emit MaxBorrowRateSet(rate);
    }

    function setMinBorrowRate(int256 rate) external {
        minBorrowRate = rate;

        emit MinBorrowRateSet(rate);
    }

    function totalAssets() public view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    function ratio() public view returns (uint256) {
        if (totalAssets() == 0) {
            return 0;
        }
        return totalSupply() / totalAssets();
    }

    function getBorrowRate(int256 excessOpenInterest_) public view returns (int256) {
        int256 _totalAssets = int256(totalAssets());

        if (_totalAssets == 0) {
            return minBorrowRate;
        }

        return minBorrowRate + ((maxBorrowRate - minBorrowRate) * int256(excessOpenInterest_)) / int256(_totalAssets);
    }

    function _updateFeeIntegrals() internal {
        // tradePair.updateFeeIntegrals();
    }
}
