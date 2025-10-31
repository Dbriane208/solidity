// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig,CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


contract RaffleTest is CodeConstants,Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public player = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    /*Events*/
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffleContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(player,STARTING_PLAYER_BALANCE);
    }

    function testConstructorSetsValuesCorrectly() public view{
        // Test that all constructor values are set correctly
        assertEq(raffle.getEntranceFee(), entranceFee, "Entrance fee not set correctly");
        assertEq(raffle.getInterval(), interval, "Interval not set correctly");
        assertEq(raffle.getGasLane(), gasLane, "Gas lane not set correctly");
        // Should not be equal because each contract creates a subscription Id -> its dynamically created
        assertNotEq(raffle.getSubscriptionId(), subscriptionId, "Subscription ID not set correctly");
        assertEq(raffle.getCallbackGasLimit(), callbackGasLimit, "Callback gas limit not set correctly");
        // Test initial state
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN), "Initial state should be OPEN");
    }

    function testFulfillRandomWordsPicksWinnerAndSendsReward() public {
        // Arrange - Set up the test
        // Need players to enter the raffle
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        
        // Add more players (optional, but good for testing)
        address player2 = makeAddr("player2");
        vm.deal(player2, STARTING_PLAYER_BALANCE);
        vm.prank(player2);
        raffle.enterRaffle{value: entranceFee}();

        // Fast forward time to trigger upkeep
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Perform upkeep to request random words
        raffle.performUpkeep("");

        // Act - Fulfill the random words request
        // We need the request ID, but since we're using a mock, we can just use any number
        uint256 requestId = 0;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1234; // Any random number
        
        // Expect the WinnerPicked event
        vm.expectEmit(true, false, false, false, address(raffle));
        emit WinnerPicked(player); // We know player will win because 1234 % 2 = 0

        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(requestId, randomWords);

        // Assert
        // Check that winner was picked
        address recentWinner = raffle.getRecentWinner();
        assertTrue(recentWinner != address(0), "Winner should be set");
        
        // Check raffle state reset
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN), "Raffle should be open");
        assertEq(raffle.getPlayersLength(), 0, "Players array should be reset");
        
        // Check winner received prize
        assertTrue(recentWinner.balance > STARTING_PLAYER_BALANCE, "Winner balance should increase");
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPlayEnough() public {
        // Arrange
        vm.prank(player);
        // Act/assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();        
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(player);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Asset
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == player);
    }

    function testEnteringRaffleEmitEvent() public {
        // Arrange
        vm.prank(player);
        // Act
        vm.expectEmit(true,false,false,false,address(raffle));
        emit RaffleEntered(player);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
        
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        // waiting for our function to enter calculating mode
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upKeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testChekUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upKeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded);

    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public{
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerfomUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        // enter with a player
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector,currentBalance,numPlayers,rState)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }  

    modifier skipFork() {
        if(block.chainid != LOCAL_CHAIN_ID){
            return;
        }
        _;
    }

    // fuzzing test
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 _requestId) public raffleEntered {
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(_requestId, address(raffle));
    }

    function testFulfillrandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork{
        // Arrange
        uint256 additionalEntrants = 3; // total 4
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = vm.addr(i);
            vm.deal(newPlayer, 1 ether);
            vm.prank(newPlayer);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));
         
        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }

}
