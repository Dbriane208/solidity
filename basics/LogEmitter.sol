// SPDX-License-Identifier: MIT
pragma solidity >=0.4.16 <0.9.0;

/*
  simple smart contract with a single function that emits an event
*/

contract LogEmmiter {
    event Log(address indexed msgSender);

    function emitLog() public {
        emit Log(msg.sender);
    }
}