// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PriceConverter} from "./PriceConverter.sol";

error NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 2e18;

    address public immutable owner;

    address[] public funders;
    mapping(address funder => uint256 amountFunded) public addressToAmountFunded;

    // executed automatically when the contract deployed
    constructor() {
        owner = msg.sender;
    }

    function fund() public payable {
        require(msg.value.getConversionRate() >= MINIMUM_USD,"didn't send enough ETH");
        funders.push(msg.sender);
        addressToAmountFunded[msg.sender] = addressToAmountFunded[msg.sender] + msg.value;
    }

    function withdraw() public onlyOwner {
        // for loop
        for(uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++){
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }

        // reset the array
        funders = new address[](0);

        //sending eth from a contract
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess,"Call failed");
    }

    modifier onlyOwner() {
       // require(msg.sender == owner, "Sender's not owner!");
       if(msg.sender != owner){revert NotOwner();}
        _;
    }

    receive() external payable {
        fund();
     }

     fallback() external payable {
        fund();
      }
}

