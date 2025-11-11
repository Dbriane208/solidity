// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;
    // some list of addresses
    // Allow someone in the lsit to claim ERC-20 tokens
    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    address[] claimers;
    bytes32 private immutable I_MERKLE_ROOT;
    IERC20 private immutable I_AIRDROP_TOKEN;
    mapping(address claimer => bool claimed) private sHasClaimed;

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    // define the message hash struct
    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    event ClaimVerified(address account, uint256 amount);
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("Merkle Airdrop", "1.0.0") {
        I_MERKLE_ROOT = merkleRoot;
        I_AIRDROP_TOKEN = airdropToken;
    }

    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        // prevent reentrancy
        if (sHasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }

        // verify the signature
        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        // calculate using the account and the amount, the hash -> leaf node;
        bytes32 leaf;
        assembly {
            // Load the free memory pointer
            let ptr := mload(0x40)
            // Store account and amount in memory
            mstore(ptr, account)
            mstore(add(ptr, 32), amount)
            // Hash the account and amount (first keccak256)
            let hash := keccak256(ptr, 64)
            // Store the hash in memory
            mstore(ptr, hash)
            // Hash again (second keccak256)
            leaf := keccak256(ptr, 32)
        }
        if (!MerkleProof.verify(merkleProof, I_MERKLE_ROOT, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }
        sHasClaimed[account] = true;
        emit ClaimVerified(account, amount);
        I_AIRDROP_TOKEN.safeTransfer(account, amount);
    }

    // verify whether the recovered signer is the expected signer/the account to airdrop tokens for
    function _isValidSignature(
        address signer,
        bytes32 digest,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, _v, _r, _s);
        return (actualSigner == signer);
    }

    // message we expect to have been signed
    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({ account: account, amount: amount })))
            );
    }

    // Getter functions
    function getMerkleRoot() external view returns (bytes32) {
        return I_MERKLE_ROOT;
    }

    function getAirdropToken() external view returns (IERC20) {
        return I_AIRDROP_TOKEN;
    }
}
