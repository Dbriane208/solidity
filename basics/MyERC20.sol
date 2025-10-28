// SPDX-License-Identifier: MIT
pragma solidity >=0.4.16 <0.9.0;

import { ERC20 } from "@openzeppelin/contracts@4.6.0/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts@4.6.0/access/AccessControl.sol";

// The contract can create new token via mint function
contract MyERC20 is ERC20,AccessControl{
    // To give access to the miner token
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("My Cyfrin CLF Token","CLF") {
        // We assign the contract owner the admin role
        _grantRole(DEFAULT_ADMIN_ROLE,msg.sender);
        _grantRole(MINTER_ROLE,msg.sender);
    }

    // A way to create the supply of token
    function mint(address to,uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to,amount);
    }
}