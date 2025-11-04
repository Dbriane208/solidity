// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract ManualToken {
    mapping(address => uint256) private s_balances;
    uint256 private constant MAX_SUPLLY = 100 ether;
    uint256 private constant DECIMALS = 18;

    constructor() {
        // assign the entire supply to the deployer
        s_balances[msg.sender] = MAX_SUPLLY;
    }

    function name() public pure returns (string memory) {
        return "Manual Token";
    }

    function totalSupply() public pure returns (uint256) {
        return MAX_SUPLLY;
    }

    function decimals() public pure returns (uint256) {
        return DECIMALS;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return s_balances[_owner];
    }

    function transfer(address _to, uint256 _amount) public {
        uint256 previousBalances = balanceOf(msg.sender) + balanceOf(_to);
        s_balances[msg.sender] -= _amount;
        s_balances[_to] += _amount;
        require(balanceOf(msg.sender) + balanceOf(_to) == previousBalances);
    }

    /**
     * Getters
     */

    function getTotalSupply() public pure returns (uint256) {
        return MAX_SUPLLY;
    }
}
