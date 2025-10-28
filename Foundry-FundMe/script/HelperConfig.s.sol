// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script{

    NetworkConfig public activeNetworkConfig;

    uint8 public constant ETH_DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 200e8;
    
    // create types for the network
    struct NetworkConfig {
        address priceFeed;
    }

    constructor(){
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaEthConfig();
        }else if(block.chainid == 1){
            activeNetworkConfig = getEthereumMainnetConfig();
        }else if(block.chainid == 84532){
            activeNetworkConfig = getBaseEthConfig();
        }else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
        
    }

    // pure functions work with their own values, dont modify blockchain state nor read it
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory){
        NetworkConfig memory sepoliaConfig = NetworkConfig({priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306});
        return sepoliaConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if(activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(ETH_DECIMALS,INITIAL_PRICE);
        vm.stopBroadcast(); 

        NetworkConfig memory anvilConfig = NetworkConfig({priceFeed: address(mockPriceFeed)});
        return anvilConfig;
    }

    function getEthereumMainnetConfig() public pure returns(NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419});
        return mainnetConfig;
    }

    function getBaseEthConfig() public pure returns (NetworkConfig memory){ 
        NetworkConfig memory baseConfig = NetworkConfig({priceFeed: 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1});
        return baseConfig;
    }

}