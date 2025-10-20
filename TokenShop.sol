// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts@5.2.0/access/Ownable.sol";
import { MyERC20 } from "./MyERC20.sol";

contract TokenShop is Ownable {
    AggregatorV3Interface internal immutable i_priceFeed;
    MyERC20 public immutable i_token;

    uint256 public constant TOKEN_DECIMALS = 18;
    uint256 public constant TOKEN_USD_PRICE = 2 * 10 ** TOKEN_DECIMALS;

    event BalanceWithdrawn();

    error TokenShop_ZeroETHSent();
    error TokenShop_CouldNotWithdraw();

    // we have set the contract owner as the contract deployer(msg.sender)
    constructor(address tokenAddress)Ownable(msg.sender) {
        i_token = MyERC20(tokenAddress);
        i_priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    receive() external payable { 
        // convert the ETH amount to a token amount to mint
        if(msg.value==0){
            revert TokenShop_ZeroETHSent();
        }

        // convert the ETH sent to the contract to a token amount to mint and then mint the tokens
        i_token.mint(msg.sender,amountToMint(msg.value));
    }

    function amountToMint(uint256 amountInETH) public view returns (uint256){
        // Sent amountETH, convert to USD amount
        uint256 ethUsd = uint256(getChainlinkDataFeedLatestAnswer()) * 10 ** 10; // ETH/USD price with 8 decimal places -> 18 decimals
        uint256 ethAmountInUsd = amountInETH * ethUsd/10 ** 18; // ETH = 18 decimals
        return (ethAmountInUsd * 10 ** TOKEN_DECIMALS)/ TOKEN_USD_PRICE; // *10** TOKEN_DECIMALS since tokenAmount needs to be in TOKEN_DECIMALS
    }

    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        (,int price,,,) = i_priceFeed.latestRoundData();
        return price;
    }

    function withdraw() external onlyOwner {
        // low level calls can be done on payable addresses
        (bool success,) = payable(owner()).call{value: address(this).balance}("");
        if(!success){
            revert TokenShop_CouldNotWithdraw();
        }
        emit BalanceWithdrawn();
    }
}