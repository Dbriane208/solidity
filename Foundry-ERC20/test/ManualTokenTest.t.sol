// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ManualToken} from "../src/ManualToken.sol";

contract ManualTokenTest is Test {
    ManualToken manualToken;

    address userA = makeAddr("user");
    uint256 private constant TOKEN_AMOUNT = 10 ether;

    function setUp() external {
        manualToken = new ManualToken();
    }

    function testTotalTokenSupplyIsMoreThanZero() public view {
        assert(manualToken.getTotalSupply() > 0);
    }
}
