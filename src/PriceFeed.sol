// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "src/interfaces/IPriceFeed.sol";

contract PriceFeed is IPriceFeed {

    uint256 public constant PRICE_PRECISION = 1e18;

    mapping(address => bytes32) public priceIds;

    constructor() {}

    function setPriceFeed(address _token, bytes32 _priceId) external {
      priceIds[_token] = _priceId;
    }

    function getPrice(address _token, bytes[] memory _priceUpdateData) external payable override returns (uint256) {
      return _getNormalizedPrice(priceIds[_token], _priceUpdateData);
    }

    function _getNormalizedPrice(bytes32 _priceId, bytes[] memory _priceUpdateData) private payable returns (uint256) {
      PythStructs.Price memory priceStruct = _getPythPriceStruct(_priceId, _priceUpdateData);

      int32 expo = priceStruct.expo;
      int64 price = priceStruct.price;

      if (price < 0) {
        // TODO: price might actually be negative and validly so
        revert('VaultPriceFeed: oracle price is negative.');
      }
      if (expo > 0) {
        // TODO: might not be appropriate to handle it like this
        revert('VaultPriceFeed: exponent is not negative.');
      }

      return (uint256(price) * PRICE_PRECISION) / 10 ** uint256(-expo);
    }

    function _getPythPriceStruct(bytes32 _priceId, bytes[] memory _priceUpdateData) private payable returns (PythStructs.Price memory) {
      uint fee = pyth.getUpdateFee(_priceUpdateData);
      pyth.updatePriceFeeds{value: fee}(_priceUpdateData);

      // TODO: perhaps use getPriceNoOlderThan
      return pyth.getPrice(_priceId);
    }
}
