// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A Sample Raffle Contract
 * @author 0xdb_
 * @notice This contract is fo r creating a sample raffle
 * @dev Implement Chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /*Errors*/
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /*Type Declarations*/
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /*State Variables*/
    uint32 constant NUM_WORDS = 1;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable I_ENTRANCEFEE;
    uint256 private immutable I_INTERVAL;
    uint256 private immutable I_SUBSCRIPTIONID;
    bytes32 private immutable I_KEYHASH;
    uint32 private immutable I_CALLBACKGASLIMIT;
    uint256 private sLastTimeStamp;
    address payable[] private sPlayers;
    address private sRecentWinner;
    RaffleState private sRaffleState;

    /*Events*/
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTRANCEFEE = entranceFee;
        I_INTERVAL = interval;
        I_SUBSCRIPTIONID = subscriptionId;
        I_KEYHASH = gasLane;
        I_CALLBACKGASLIMIT = callbackGasLimit;

        sRaffleState = RaffleState.OPEN;
        sLastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < I_ENTRANCEFEE) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (sRaffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        sPlayers.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink nodes will all to see
     * if the lottery is ready to have a winner picked
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upKeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */

    // The function checks when the winner should be picked?
    function checkUpKeep(
        bytes memory /*checkData*/
    )
        public
        view
        returns (
            bool upKeepNeeded,
            bytes memory /*performData*/
        )
    {
        bool timeHasPassed = (block.timestamp - sLastTimeStamp > I_INTERVAL);
        bool isOpen = sRaffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = sPlayers.length > 0;
        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upKeepNeeded, "");
    }

    function performUpkeep(
        bytes calldata /*performData */
    )
        external
    {
        // Check to see if enought time has passed
        (bool upKeepNeeded,) = checkUpKeep("");
        if (!upKeepNeeded) {
            // custom errors w/parameters gives more clarity
            revert Raffle__UpkeepNotNeeded(address(this).balance, sPlayers.length, uint256(sRaffleState));
        }

        sRaffleState = RaffleState.CALCULATING;
        // Get our random number : Request RNG -> Get RNG
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_KEYHASH,
            subId: I_SUBSCRIPTIONID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: I_CALLBACKGASLIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    )
        internal
        override
    {
        // Checks
        // Effect(Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % sPlayers.length;
        address payable recentWinner = sPlayers[indexOfWinner];
        sRecentWinner = recentWinner;

        sRaffleState = RaffleState.OPEN;
        sPlayers = new address payable[](0);
        sLastTimeStamp = block.timestamp;

        // Interactions(External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}(""); // we pay the winner
        if (!success) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        emit WinnerPicked(sRecentWinner);
    }

    /**
     * Getters
     */

    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCEFEE;
    }

    function getInterval() external view returns (uint256) {
        return I_INTERVAL;
    }

    function getGasLane() external view returns (bytes32) {
        return I_KEYHASH;
    }

    function getSubscriptionId() external view returns (uint256) {
        return I_SUBSCRIPTIONID;
    }

    function getCallbackGasLimit() external view returns (uint32) {
        return I_CALLBACKGASLIMIT;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return sLastTimeStamp;
    }

    function getRaffleState() external view returns (RaffleState) {
        return sRaffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address){
        return sPlayers[indexOfPlayer];
    }

    function getPlayersLength() external view returns (uint256) {
        return sPlayers.length;
    }

    function getRecentWinner() external view returns (address) {
        return sRecentWinner;
    }
}
