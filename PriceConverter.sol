// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
     function getprice() internal  view returns(uint256){
        // Get information from another contract we need address and abi
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        (,int256 price,,,) = priceFeed.latestRoundData();
        // we're multiplying price with 1e10 to match the decimal 18 decimal places in our msg.value
        return uint256(price * 1e10);
    }

    function getConversionRate(uint256 ethAmount) internal  view returns(uint256){
        // we're dividing with 1e18 to normalize the zeros
        uint256 ethPrice = getprice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUsd;
    }

    function getVersion() internal view returns (uint256){
        return AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306).version();
    }
}