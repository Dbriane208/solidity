// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.3.0/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts@1.3.0/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/*
 The goal is to rooll a dice in a smart contract
*/

contract HousePicker is VRFConsumerBaseV2Plus {
    // value out of range of houses
    uint256 private constant ROLL_IN_PROGRESS = 4;

    // Chainlink subscription ID
    uint256 public s_subscriptionId;

    // Sepolia coordianator address on the network
    address public constant VRF_CORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;

    // Identifies the VRF gas lane to use
    bytes32 public constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    uint32 public callbackGasLimit = 40000; // max gas for callback fn -> fulfillRandomWords
    uint16 public requestConfirmations = 3; // No. of block confirmations to wait before the request is returned
    uint32 public numWords = 1; // no. of random values to request

    mapping(uint256 => address) private s_rollers; // Maps VRF request IDs to user addresses
    mapping(address => uint256) private s_results; // Map user addresses to their random result

    event DiceRolled(uint256 indexed requestId,address indexed roller); // emitted when randomness is requested
    event DiceLanded(uint256 indexed requestId,uint256 indexed result); // emitted when randomness is received

    // initializes the contract with a VRF subscription ID.
    // Passes the VRF coordinator address to the parent contract
    constructor(uint256 subscriptionId) VRFConsumerBaseV2Plus(VRF_CORDINATOR) {
        s_subscriptionId = subscriptionId;
    }

    // Request randomness function
    function rollDice() public returns (uint256 requestId) {
        // checks that the caller hasn't already rolled
        require(s_results[msg.sender] == 0,"Already rolled");

        // Requests a random number from Chainlink VRF
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) // set to false inorder to use LINK instead of Eth
                )
            })
        );

        s_rollers[requestId] = msg.sender;
        s_results[msg.sender] = ROLL_IN_PROGRESS;
        emit DiceRolled(requestId, msg.sender);
    }

    // callback function -> called by VRF when random number is returned
    function fulfillRandomWords(uint256 requestId,uint256[] calldata randomwords) internal override {
        uint256 d6Value = (randomwords[0] % 4);
        s_results[s_rollers[requestId]] = d6Value;
        emit DiceLanded(requestId, d6Value);
    }

    function house(address player) public view returns (string memory) {
        require(s_results[player] != 0,"Dice not rolled");
        require(s_results[player] != ROLL_IN_PROGRESS,"Roll in progress");
        return _getHouseName(s_results[player]);
    }

    function _getHouseName(uint256 id) private pure returns(string memory) {
        string[4] memory houseNames = [
            "Gryffindor",
            "Hufflepuff",
            "Slytherin",
            "Ravenclaw"
        ];
        return houseNames[id];
    }

}