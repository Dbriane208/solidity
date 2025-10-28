// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice(AggregatorV3Interface priceFeed) internal view returns(uint256) {
        (,int256 price,,,) = priceFeed.latestRoundData();
        // Multiplying price with 1e10 to match the 18 decimal places in our msg.value
        // Check if price is negative first
        require(price >= 0, "Negative price");
        // Safe conversion: first cast to uint256, then multiply
        return uint256(price) * 1e10;
    }

    function getConversionRate(uint256 ethAmount,AggregatorV3Interface priceFeed) internal view returns(uint256) {
        // we're dividing with 1e18 to normalize the zeros
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUsd;        
    }

    function getVersion(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        return priceFeed.version();
    }

}