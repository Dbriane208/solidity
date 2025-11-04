// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

interface MintableToken {
    function mint(address, uint256) external;
}

contract OurTokenTest is StdCheats, Test {
    OurToken public ourToken;
    DeployOurToken public deployer;

    address public bob = makeAddr("bob");
    address public alice = makeAddr("alice");

    uint256 public constant STARTING_BALANCE = 100 ether;

    /**
     * @notice Setup function runs before each test
     * @dev This ensures each test starts with a fresh state
     * 1. Deploy the token contract
     * 2. Give Bob some tokens to work with
     */
    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        // Give some tokens to bob for testing
        // msg.sender here is the address that the deployed token
        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    /**
     * @notice Tests that the intial supply matches what was deployed
     * @dev This verifies the constructor currently minted the initial supplly
     */
    function testInitialSupply() public view {
        assertEq(ourToken.totalSupply(), deployer.INITIAL_SUPPLY());
    }

    /**
     * @notice Test that users cannot mint new tokens
     * @dev Our token doesn't have a mint function, so this should revert
     * We try to call a non-existent mint function and expect it to fail
     */
    function testUsersCantMint() public {
        vm.expectRevert();
        MintableToken(address(ourToken)).mint(address(this), 1);
    }

    // ===========================================
    // Transfer Tests
    // ===========================================

    /**
     * @notice Test basic token transfer functionality
     * @dev Steps:
     * 1. Bob starts with STARTING_BALANCE tokens (set in setUp)
     * 2. Bob transfers 10 tokens to Alice
     * 3. Verify Alice received the tokens and Bob's balance decreased
     */
    function testTransfer() public {
        // Arrange - set the amount to transfer
        uint256 amount = 10 ether;

        // Act - Bob sends tokens to Alice
        vm.prank(bob); // Next call will be from bob's address
        bool success = ourToken.transfer(alice, amount);

        // Assert - check balances updated correctly
        assertTrue(success);
        assertEq(ourToken.balanceOf(alice), amount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - amount);
    }

    /**
     * @notice Tests that Transfer event is emitted correctly
     * @dev Events are important for off-chain tracking of token movements
     * We use vm.expectEmit to verify the event is emitted with correct parameters
     * Parameters: (indexed from,indexed to,value)
     */
    function testTransferEmitsEvent() public {
        uint256 amount = 10 ether;

        // Tell foundry to expect an event with these parameters
        // (checkTopic1,checkTopic2,checkTopic3,calldata)
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(bob, alice, amount); // The event we expect

        // Now perform the action that should emit the event
        vm.prank(bob);
        ourToken.transfer(alice, amount);
    }

    /**
     * @notice Tests that transfer fails when sender has insufficient balance
     * @dev Bob has STARTING_BALANCE, trying to send more should revert
     */
    function testTransferFailsWithInsufficientBalance() public {
        uint256 amount = STARTING_BALANCE + 1;

        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(alice, amount);
    }

    /**
     * @notice Tests that transfer to zero address fails
     * @dev ERC20 standard requires transfers to address(0) to revert
     * This prevents accidental token burning
     */
    function testTransferToZeroAddressFails() public {
        uint256 amount = 10 ether;

        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(address(0), amount);
    }

    /**
     * @notice Tests transfer of zero tokens
     * @dev Transferring 0 tokens should succed but not change any balances
     * This is valid according to ERC20 standard
     */
    function testTransferZeroAmount() public {
        vm.prank(bob);
        bool success = ourToken.transfer(alice, 0);

        assertTrue(success);
        assertEq(ourToken.balanceOf(alice), 0);
    }

    /**
     * @notice Tests that a user can transfer tokens to themselves
     * @dev self-transfers should work and leave balance unchanged
     */
    function testTransferToSelf() public {
        uint256 initialBalance = ourToken.balanceOf(bob);
        uint256 amount = 10 ether;

        vm.prank(bob);
        bool success = ourToken.transfer(bob, amount);

        assertTrue(success);
        assertEq(ourToken.balanceOf(bob), initialBalance);
    }

    // ===========================================
    // Allowance Tests
    // These tests verify the approve/allowed mechanism
    // which allows one address to spend tokens on behalf of another
    // ===========================================

    /**
     * @notice Tests the approve function
     * @dev Approve allows a spender to withdraw from your account multiple times
     * Steps:
     * 1. Bob approves Alice to spend 50 tokens
     * 2. Check that the allowance is recorded correctly
     */
    function testApprove() public {
        uint256 amount = 50 ether;

        vm.prank(bob);
        bool success = ourToken.approve(alice, amount);

        assertTrue(success);
        assertEq(ourToken.allowance(bob, alice), amount);
    }

    /**
     * @notice Tests that Approval event is emitted
     * @dev The Approval event lets off-chain systems track spending permissions
     * Event signature: Approval(address indexed owner,address indexed spender,uint256 value)
     */
    function testApproveEmitsEvent() public {
        uint256 amount = 50 ether;

        vm.expectEmit(true, true, false, true);
        emit IERC20.Approval(bob, alice, amount);

        vm.prank(bob);
        ourToken.approve(alice, amount);
    }

    /**
     * @notice Tests that approving zero address fails
     * @dev Approving address(0) should revert to prevent mistakes
     */
    function testApproveZeroAddress() public {
        uint256 amount = 50 ether;

        vm.prank(bob);
        vm.expectRevert();
        ourToken.approve(address(0), amount);
    }

    /**
     * @notice Tests that approvals can be overwritten
     * @dev You can change an existing allowance by calling approve again
     * This is useful for updating or revoking permissions
     */
    function testApproveOverwrite() public {
        uint256 firstAmount = 50 ether;
        uint256 secondAmount = 75 ether;

        vm.startPrank(bob); // Start persistent prank (multiple calls from bob)

        // First approval
        ourToken.approve(alice, firstAmount);
        assertEq(ourToken.allowance(bob, alice), firstAmount);

        // Second approval overwrites the first
        ourToken.approve(alice, secondAmount);
        assertEq(ourToken.allowance(bob, alice), secondAmount);

        vm.stopPrank(); // Stop the persistent prank
    }

    // ===========================================
    // TransferFrom Tests
    // These test verify the transferFrom function which allows
    // approved spenders to move tokens on behalf of the owner
    // ===========================================

    /**
     * @notice Tests the complete transferFrom flow
     * @dev TransferFrom is the core of the allowance
     * Steps:
     * 1. Bob approves Alice to spend 50 tokens
     * 2. Alice uses transferFrom to move 30 tokens from Bob to herself
     * 3. Verify balances updated and allowwance decreased
     */

    function testTransferFrom() public {
        uint256 approvalAmount = 50 ether;
        uint256 transferAmount = 30 ether;

        // Bob approves Alice to spend tokens
        vm.prank(bob);
        ourToken.approve(alice, approvalAmount);

        // Alice transfers tokens from Bob to herself
        vm.prank(alice);
        bool success = ourToken.transferFrom(bob, alice, transferAmount);

        // Assert everything worked correctly
        assertTrue(success);
        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.allowance(bob, alice), approvalAmount - transferAmount);
    }

    /**
     * @notice Tests that transferFrom emits Transfer event
     * @dev Even though Alice initiated the transfer the event show tokens moved from Bob to Alice
     */
    function testTransferFromEmitsEvent() public {
        uint256 approvalAmount = 50 ether;
        uint256 transferAmount = 30 ether;

        // Bob approves Alice
        vm.prank(bob);
        ourToken.approve(alice, approvalAmount);

        // Expect Transfer event (NOT from Alice, but from Bob to Alice)
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(bob, alice, transferAmount);

        // Alice performs the transfer
        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);
    }

    /**
     * @notice Tests that transferFrom fails with insufficient allowance
     * @dev Alice is approved for 30 tokens but tries to transfer 50
     * This should revert to prevent unauthorized spending
     */
    function testTransferFromFailsWithInsufficientAllowance() public {
        uint256 approvalAmount = 30 ether;
        uint256 transferAmount = 50 ether; // more than approved

        vm.prank(bob);
        ourToken.approve(alice, approvalAmount);

        // This should fail - Alice doesn't have enough allowance
        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, transferAmount);
    }

    /**
     * @notice Tests transferFrom fails when owner has insufficient balance
     * @dev Even with high allowance, can't transfer more than owner has
     * Alice is approved for a lot, but Bob doesn't have enough tokens
     */
    function testTransferFromFailsWithInsufficientBalance() public {
        uint256 approvalAmount = STARTING_BALANCE + 100 ether;
        uint256 transferAmount = STARTING_BALANCE + 50 ether;

        vm.prank(bob);
        ourToken.approve(alice, approvalAmount);

        // Should fial - Bob doesn't have enough tokens
        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, transferAmount);
    }

    /**
     * @notice Tests that transferFrom to zero address fails
     * @dev Can't transfer to address(0) even with proper allownace
     */
    function testTransferFromToZeroAddressFails() public {
        uint256 amount = 10 ether;

        vm.prank(bob);
        ourToken.approve(alice, amount);

        // Try to transfer to zero address - should fail
        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, address(0), amount);
    }

    /**
     * @notice Tests that transferFrom fails without approval
     * @dev Alice tries to transfer Bob's tokens without any approval
     * This should always fail to prevent theft
     */
    function testTransferFromWithoutApprovalFails() public {
        uint256 amount = 10 ether;

        // No approval step - Alice tries to transfer directly
        vm.prank(alice);
        vm.expectRevert(); // Should fail - no allowance
        ourToken.transferFrom(bob, alice, amount);
    }

    /**
     * @notice Tests transferFrom with maximum allowance
     * @dev When allowance is type(uint256).max, OpenZeppelin treats it as "infinite"
     * After transfer, the allowance stays at max instead of decreasing
     * This is a gas optimization for unlimited approvals
     */
    function testTransferFromWithMaxAllowance() public {
        uint256 transferAmount = 10 ether;

        // Approve maximum possible amount (infinite approval)
        vm.prank(bob);
        ourToken.approve(alice, type(uint256).max);

        // Transfer should succeed
        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        // OpenZeppelin ERC20 keeps max allowance at max after transfer (gas optimization)
        assertEq(ourToken.allowance(bob, alice), type(uint256).max);
    }

    // ===========================================
    // Token Metadata Tests
    // These verify the ERC20 token information functions
    // ===========================================

    /**
     * @notice Tests that token name is correctly set
     * @dev Name is set in the constructor via ERC20("OurToken", "OT")
     */
    function testTokenName() public view {
        assertEq(ourToken.name(), "OurToken");
    }

    /**
     * @notice Tests that token symbol is correctly set
     * @dev Symbol is set in the constructor via ERC20("OurToken", "OT")
     */
    function testTokenSymbol() public view {
        assertEq(ourToken.symbol(), "OT");
    }

    /**
     * @notice Tests that token decimals is 18 (standard)
     * @dev OpenZeppelin ERC20 uses 18 decimals by default
     * This means 1 token = 1 * 10^18 smallest units
     */
    function testTokenDecimals() public view {
        assertEq(ourToken.decimals(), 18);
    }

    // ===========================================
    // Balance Tests
    // ===========================================

    /**
     * @notice Tests balanceOf function
     * @dev Bob received STARTING_BALANCE in setUp, verify it's correct
     */
    function testBalanceOf() public view {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    /**
     * @notice Tests that zero address has zero balance
     * @dev Querying balanceOf(address(0)) should work and return 0
     */
    function testBalanceOfZeroAddress() public view {
        assertEq(ourToken.balanceOf(address(0)), 0);
    }

    // ===========================================
    // Fuzz Tests
    // Fuzz testing runs the same test with many random inputs
    // to find edge cases and unexpected behaviors
    // Foundry will run each test 256 times (default) with random values
    // ===========================================

    /**
     * @notice Fuzz test for transfer function
     * @dev Tests transfer with random addresses and amounts
     * @param to Random recipient address
     * @param amount Random transfer amount
     *
     * vm.assume() filters out invalid inputs:
     * - Avoids zero address (would revert)
     * - Ensures amount doesn't exceed balance
     */
    function testFuzzTransfer(address to, uint256 amount) public {
        // Filter out invalid test cases
        vm.assume(to != address(0)); // Can't transfer to zero address
        vm.assume(amount <= STARTING_BALANCE); // Can't transfer more than balance

        vm.prank(bob);
        bool success = ourToken.transfer(to, amount);

        // Verify the transfer worked correctly
        assertTrue(success);
        assertEq(ourToken.balanceOf(to), amount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - amount);
    }

    /**
     * @notice Fuzz test for approve function
     * @dev Tests approval with random spender addresses and amounts
     * @param spender Random spender address
     * @param amount Random approval amount
     */
    function testFuzzApprove(address spender, uint256 amount) public {
        vm.assume(spender != address(0)); // Can't approve zero address

        vm.prank(bob);
        bool success = ourToken.approve(spender, amount);

        assertTrue(success);
        assertEq(ourToken.allowance(bob, spender), amount);
    }

    /**
     * @notice Fuzz test for transferFrom function
     * @dev Tests transferFrom with random approval and transfer amounts
     * @param approvalAmount Random approval amount
     * @param transferAmount Random transfer amount
     *
     * This tests the relationship between approval limits and transfers
     */
    function testFuzzTransferFrom(uint256 approvalAmount, uint256 transferAmount) public {
        // Ensure valid test conditions
        vm.assume(approvalAmount <= STARTING_BALANCE); // Can't approve more than we have
        vm.assume(transferAmount <= approvalAmount); // Can't transfer more than approved

        // Setup: Bob approves Alice
        vm.prank(bob);
        ourToken.approve(alice, approvalAmount);

        // Act: Alice transfers from Bob
        vm.prank(alice);
        bool success = ourToken.transferFrom(bob, alice, transferAmount);

        // Assert: Verify everything updated correctly
        assertTrue(success);
        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
    }

    // ===========================================
    // Edge Case Tests
    // These test unusual but valid scenarios
    // ===========================================

    /**
     * @notice Tests that one user can approve multiple different spenders
     * @dev Bob should be able to give allowances to multiple addresses simultaneously
     * Each approval is independent
     */
    function testMultipleApprovals() public {
        vm.startPrank(bob);
        // Bob approves both Alice and the test contract
        ourToken.approve(alice, 50 ether);
        ourToken.approve(address(this), 30 ether);
        vm.stopPrank();

        // Both approvals should be active
        assertEq(ourToken.allowance(bob, alice), 50 ether);
        assertEq(ourToken.allowance(bob, address(this)), 30 ether);
    }

    /**
     * @notice Tests a complex multi-step transfer scenario
     * @dev This simulates real-world DeFi interactions:
     * 1. Bob approves Alice (like approving a DEX)
     * 2. Alice uses transferFrom (DEX executes the trade)
     * 3. Alice transfers to another address (DEX sends to recipient)
     *
     * This tests that multiple operations work correctly together
     */
    function testComplexTransferScenario() public {
        // Step 1: Bob approves Alice to spend 50 tokens
        vm.prank(bob);
        ourToken.approve(alice, 50 ether);

        // Step 2: Alice transfers 20 tokens from Bob to herself
        vm.prank(alice);
        ourToken.transferFrom(bob, alice, 20 ether);

        // Step 3: Alice transfers 10 tokens to the test contract
        vm.prank(alice);
        ourToken.transfer(address(this), 10 ether);

        // Verify final state of all accounts
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - 20 ether); // Bob lost 20
        assertEq(ourToken.balanceOf(alice), 10 ether); // Alice has 10
        assertEq(ourToken.balanceOf(address(this)), 10 ether); // Contract has 10
        assertEq(ourToken.allowance(bob, alice), 30 ether); // Allowance decreased
    }

    // ===========================================
    // Invariant Tests
    // These test properties that should ALWAYS be true
    // ===========================================

    /**
     * @notice Tests that total supply never changes
     * @dev This is a critical invariant for ERC20 tokens without mint/burn
     * No matter how many transfers happen, total supply stays constant
     *
     * This protects against:
     * - Accidental token creation
     * - Token loss/destruction
     * - Arithmetic errors
     */
    function testTotalSupplyRemainsConstant() public {
        uint256 initialTotalSupply = ourToken.totalSupply();

        // Perform various operations that move tokens around
        vm.prank(bob);
        ourToken.transfer(alice, 10 ether);

        vm.prank(bob);
        ourToken.approve(alice, 50 ether);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, 20 ether);

        // Total supply should remain unchanged after all operations
        // Tokens are moved, not created or destroyed
        assertEq(ourToken.totalSupply(), initialTotalSupply);
    }
}

