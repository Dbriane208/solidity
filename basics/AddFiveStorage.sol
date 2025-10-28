// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SimpleStorage} from "./SimpleStorage.sol";

contract AddFiveStorage is SimpleStorage{
    // overriding the set function
    function set(uint256 _newNo) public override {
        storedData = _newNo + 5;
    }
}