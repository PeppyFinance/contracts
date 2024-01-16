// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

// import ownable.sol
import "openzeppelin/access/Ownable.sol";
import "src/interfaces/IController.sol";

contract Controller is Ownable, IController {
    mapping(address => bool) public isTradePair;
    mapping(address => bool) public isLiquidityPool;

    function addTradePair(address _tradePair) external onlyOwner {
        isTradePair[_tradePair] = true;
    }

    function addLiquidityPool(address _liquidityPool) external onlyOwner {
        isLiquidityPool[_liquidityPool] = true;
    }

    function removeTradePair(address _tradePair) external onlyOwner {
        isTradePair[_tradePair] = false;
    }

    function removeLiquidityPool(address _liquidityPool) external onlyOwner {
        isLiquidityPool[_liquidityPool] = false;
    }
}
