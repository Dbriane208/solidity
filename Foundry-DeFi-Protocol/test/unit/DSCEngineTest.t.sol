// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { DeployDSC } from "../../script/DeployDSC.s.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { console2 } from "forge-std/console2.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    DSCEngine dsce;

    address[] collateralTokens;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant START_BALANCE = 20 ether;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public  amountToMint= 100 ether;

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    function setUp() public {
        deployer = new DeployDSC();
        config = new HelperConfig();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
    }

    ///////////////////////
    // Constructor Tests ///
    ///////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesNotMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAndpriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether; // for us this translates to 100 usd bt now in wei
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    function testConstructorSetsTokenAddressesToPriceFeeds() public {
        // Arrange
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);

        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        tokenAddresses[0] = weth;
        tokenAddresses[1] = wbtc;

        priceFeedAddresses[0] = ethUsdPriceFeed;
        priceFeedAddresses[1] = btcUsdPriceFeed;

        // Act
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        address retrievedEthPriceFeed = dsce.getPriceFeed(weth);
        address retrievedBtcPriceFeed = dsce.getPriceFeed(wbtc);

        // Assert
        assertEq(retrievedEthPriceFeed, ethUsdPriceFeed);
        assertEq(retrievedBtcPriceFeed, btcUsdPriceFeed);
    }

    function testConstructorAddsCollateralTokens() public {
        // Arrange
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);

        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        tokenAddresses[0] = weth;
        tokenAddresses[1] = wbtc;

        priceFeedAddresses[0] = ethUsdPriceFeed;
        priceFeedAddresses[1] = btcUsdPriceFeed;

        // Act
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsce));

        // verify collateral tokens are added
        collateralTokens = dsce.getCollateralTokens();

        // Assert
        assertEq(collateralTokens.length, 2);
        assertEq(collateralTokens[0], weth);
        assertEq(collateralTokens[1], wbtc);
    }

    function testConstructorSetsDSCAddress() public {
        // Arrange
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);

        tokenAddresses[0] = weth;
        priceFeedAddresses[0] = ethUsdPriceFeed;

        // Act
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        // Assert - DSC Address is set correctly
        address retrievedDscAddress = address(dsce.getDSCAddress());
        assertEq(retrievedDscAddress, address(dsc));
    }

    function testConstructorWorksWithOneToken() public {
        // Arrange
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);

        tokenAddresses[0] = weth;
        priceFeedAddresses[0] = ethUsdPriceFeed;

        // Act
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        collateralTokens = dsce.getCollateralTokens();

        // Assert
        assertEq(collateralTokens.length, 1);
        assertEq(collateralTokens[0], weth);
    }

    function testConstructorWorksWithEmptyArrays() public {
        // Should not revert with empty but matching arrays
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        collateralTokens = dsce.getCollateralTokens();

        assertEq(collateralTokens.length, 0);
    }

    ////////////////////
    // Price Tests  ///
    ////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18
        uint256 expectedUsd = 30_000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    ///////////////////////////////
    // DepositCollateral Tests  ///
    //////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfTokenNotAllowed() public {
        // Create a completely different token not registered in the engine
        ERC20Mock unregisteredToken = new ERC20Mock("Unregistered", "UNREG", USER, 100 ether);

        vm.startPrank(USER);
        unregisteredToken.approve(address(dsce), AMOUNT_COLLATERAL);

        // Should revert because this token was never passed to the constructor
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(unregisteredToken), 1);
        vm.stopPrank();
    }

    function testDepositCollateralIncreasesUserBalance() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 userBalance = dsce.getCollateralBalanceOfUser(USER, address(weth));
        assertEq(userBalance, AMOUNT_COLLATERAL);
    }

    function testUserBalanceIncreasesAfterDeposit() public {
        // Arrange: Check DSCEngine record before
        uint256 userCollateralBalanceBefore = dsce.getCollateralBalanceOfUser(USER, weth);
        console2.log("Before Balance", userCollateralBalanceBefore);

        // add the collateral deposited
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, START_BALANCE);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        // Act
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // Assert
        uint256 userCollateralBalanceAfter = dsce.getCollateralBalanceOfUser(USER, weth);
        console2.log("After Balance", userCollateralBalanceAfter);
        assertGt(userCollateralBalanceAfter, userCollateralBalanceBefore);
    }

    function testExpectEmitCollateralDeposited() public {
        vm.startPrank(USER);

        ERC20Mock(weth).mint(USER, START_BALANCE);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        // Act
        vm.expectEmit(true, true, true, false,address(dsce));
        emit CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testExpectFailiToDepositCollateralWithoutMinting() public depositedCollateral() {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance,0);
    }

    function testExpectFailCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted,uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedDepositedAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositedAmount, AMOUNT_COLLATERAL);
    }

    //////////////////////
    // Mintdsc Tests  ///
    /////////////////////

    function testRevertsIfHealthFactorIsBroken() public  depositedCollateral {

        (,int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint= (AMOUNT_COLLATERAL * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();

        vm.startPrank(USER);
        uint256 expectedHealthFactor = dsce.calculateHealthFactor(amountToMint, dsce.getUsdValue(weth,AMOUNT_COLLATERAL));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.mintDsc(amountToMint);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral{
        vm.startPrank(USER);
        dsce.mintDsc(amountToMint);

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, amountToMint);
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, START_BALANCE);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZero.selector);
        dsce.mintDsc(0);
        
        vm.stopPrank();
    }
    
    // This test needs it's own custom setup
    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintDSC mockDsc = new MockFailedMintDSC();
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;

        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses,priceFeedAddresses,address(mockDsc));
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(mockDsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MintedFailed.selector);
        mockDsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);

        vm.stopPrank();
    }

}
