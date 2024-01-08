// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IController {
    function addTradePair(address _tradePair) external;
    function addLiquidityPool(address _liquidityPool) external;
    function removeTradePair(address _tradePair) external;
    function removeLiquidityPool(address _liquidityPool) external;
    function isTradePair(address _address) external view returns (bool);
    function isLiquidityPool(address _address) external view returns (bool);
}
