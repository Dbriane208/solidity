// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { MerkleAirdrop } from "../../src/MerkleAirdrop.sol";
import { BagelToken } from "../../src/BagelToken.sol";
import { DeployMerkleAirdrop } from "../../script/DeployMerkleAirdrop.s.sol";
import { ZkSyncChainChecker } from "foundry-devops/src/ZkSyncChainChecker.sol";

contract MerkleAirdropTest is Test, ZkSyncChainChecker {
    MerkleAirdrop public airdrop;
    BagelToken public token;
    address gasPayer;
    address user;
    uint256 userPrivKey;

    bytes32 merkleRoot = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 amountToCollect = (25 * 1e18); // 25.000000
    uint256 amountToSend = amountToCollect * 4;

    bytes32 proofOne = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proofTwo = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] proof = [proofOne, proofTwo];

    function setUp() public {
        if (!isZkSyncChain()) {
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (airdrop, token) = deployer.deployMerkleAirdrop();
        } else {
            token = new BagelToken();
            airdrop = new MerkleAirdrop(merkleRoot, token);
            token.mint(token.owner(), amountToSend);
            token.transfer(address(airdrop), amountToSend);
            (user, userPrivKey) = makeAddrAndKey("user");
        }

        gasPayer = makeAddr("gasPayer");
        (user,userPrivKey) = makeAddrAndKey("user");
    }

    function signMessage(uint256 privKey,address account) public view returns (uint8 v, bytes32 r,bytes32 s){
        bytes32 hashedMessage = airdrop.getMessageHash(account, amountToCollect);
        (v,r,s) = vm.sign(privKey,hashedMessage);
    }

    function testUsersCanClaim() public {
        uint256 startingBalance = token.balanceOf(user);

        // get the signature
        vm.startPrank(user);
        (uint8 v,bytes32 r, bytes32 s) = signMessage(userPrivKey, user);
        vm.stopPrank();


        vm.prank(gasPayer);
        airdrop.claim(user, amountToCollect, proof, v, r, s);
        uint256 endingBalance = token.balanceOf(user);
        console2.log("Ending Balance: ", endingBalance);
        assertEq(endingBalance - startingBalance, amountToCollect);
    }
}
