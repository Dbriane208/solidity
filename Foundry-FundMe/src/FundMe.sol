// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error FundMe__NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 2e18;
    address public immutable I_OWNER;
    address[] public s_funders;
    mapping(address => uint256) private s_addressToAmountFunded;
    AggregatorV3Interface private s_priceFeed;

    // executed automatically when the contract is deployed
    constructor(address priceFeed) {
        I_OWNER = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "didn't send enough ETH");
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] = s_addressToAmountFunded[msg.sender] + msg.value;
    }

    function withdraw() public onlyOwner {
        // for loop
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }

        // rest the array
        s_funders = new address[](0);

        // sending eth from a contract
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    function cheaperWithdraw() public onlyOwner {
        address[] memory funders = s_funders;
        for (uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool success,) = I_OWNER.call{value: address(this).balance}("");
        require(success);
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != I_OWNER) revert FundMe__NotOwner();
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    /* 
        The getter functions allows us test our code
        @notice Gets the amount that an address has funded
        @param fundingingAddress the address of the funder
        @return the amount funded
    */
   function getAddressToAmountFunded(address fundingAddress) public view returns(uint256) {
    return s_addressToAmountFunded[fundingAddress];
   }

   function getFunder(uint256 index) public view returns (address) {
    return s_funders[index];
   }

   function getOwner() public view returns (address) {
    return I_OWNER;
   }

   function getPriceFeed() public view returns(AggregatorV3Interface) {
    return s_priceFeed;
   }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }
}
