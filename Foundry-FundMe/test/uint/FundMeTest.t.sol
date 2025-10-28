// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {console2} from "forge-std/console2.sol";
import {DeployedFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); // user who will send the test funds
    uint256 constant SEND_VALUE = 0.1 ether; //100000000000000000
    uint256 constant STARTING_BALANCE = 10 ether; // fund the test user with some ETHs

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployedFundMe deployFundMe = new DeployedFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER,STARTING_BALANCE);
    }

    function testMinimumDollarIsTwo() public view{
        assertEq(fundMe.MINIMUM_USD(),2e18);        
    }

    function testOwnerIsMsgSender() public view{
        console2.log("Owner address",fundMe.I_OWNER());
        console2.log("Fundme owner adress",msg.sender);
        assertEq(fundMe.I_OWNER(), msg.sender);        
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();  // We expect this to revert with any message
        fundMe.fund();  // Sending 0 ETH, which will definitely be less than MINIMUM_USD
    }

    function testPriceFeedVersionIsAccurate() public view{
        uint256 version = fundMe.getVersion();
        assertEq(version,4);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    //for clean code and reusability
    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance,0);
        assertEq(startingFundMeBalance + startingOwnerBalance,endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            hoax(address(i),SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }
        
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for(uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            hoax(address(i),SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
    }
}