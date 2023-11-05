// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "src/interfaces/IPriceFeed.sol";
import "pyth-sdk-solidity/IPyth.sol";

contract PriceFeed is IPriceFeed {

    IPyth pyth;
    int256 public constant PRICE_PRECISION = 1e18;

    mapping(string => bytes32) public priceIds;

    constructor(address _pyth) {
        pyth = IPyth(_pyth);
    }

    function setPriceFeed(string calldata _index, bytes32 _priceId) external override {
        priceIds[_index] = _priceId;
    }

    function getPrice(string calldata _index, bytes[] memory _updateData) external payable override returns (int256) {
        PythStructs.Price memory price = _getPrice(priceIds[_index], _updateData);
        return _normalize(price);
    }

    function _normalize(PythStructs.Price memory price) internal pure returns (int256) {
        int32 expo = price.expo;
        int64 priceVal = price.price;

        require(priceVal >= 0, 'PriceFeed: oracle price is negative.');
        require(expo <= 0, 'PriceFeed: exponent is not negative.');

        uint256 absoluteExpo = uint256(-int256(expo)); // Convert to positive uint256
        int256 normalizedPrice = (priceVal * PRICE_PRECISION) / int256(10 ** absoluteExpo);

        return normalizedPrice;
    }

    function _getPrice(bytes32 _priceId, bytes[] memory _updateData) internal returns (PythStructs.Price memory) {
        // uint fee = pyth.getUpdateFee(_updateData);
        // pyth.updatePriceFeeds{value: fee}(_updateData);

        return pyth.getPriceUnsafe(_priceId);
    }
}
