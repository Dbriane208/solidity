// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { DecentralizedStableCoin } from "./DecentralizedStableCoin.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OracleLib, AggregatorV3Interface } from "./libraries/OrcleLib.sol";
/**
 * @title DSCEngine
 * @author 0xdb_
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
 * This stablecoin has the properties:
 *  1. Exogenous Collateral
 *  2. Dollar Pegged
 *  3. Algorithimically stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by wETH and wBTC.
 * Our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the $ backed
 * value of all the DSC.
 *
 * @notice This contract is the core of the DSC system. It handles all the logic for mining
 * and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO (DAI) systems.
 */

contract DSCEngine is ReentrancyGuard {
    //////////////
    // Errors   //
    //////////////
    error DSCEngine__NeedMoreThanZero();
    error DSCEngine__TokenAndpriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintedFailed();
    error DSCEngine__HealthFactorWork();
    error DSCEngine__HealthFactorNotImproved();

    ///////////////////
    // Types         //
    ///////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////////
    // State Variables   //
    //////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION_FEED = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //  You need to be 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // this mean 10% bonus

    mapping(address token => address priceFeed) private sPriceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private sCollateralDeposited;
    mapping(address user => uint256 amountDscMinted) private sDscMinted;
    address[] private sCollateralTokens;

    DecentralizedStableCoin immutable I_DSC;

    //////////////
    // Events   //
    //////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed reedemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    //////////////
    // Modifiers//
    //////////////
    function _moreThanZero(uint256 amount) internal pure {
        if (amount == 0) {
            revert DSCEngine__NeedMoreThanZero();
        }
    }

    function _isAllowedToken(address token) internal view {
        if (sPriceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
    }

    modifier moreThanZero(uint256 amount) {
        _moreThanZero(amount);
        _;
    }

    modifier isAllowedToken(address token) {
        _isAllowedToken(token);
        _;
    }

    //////////////
    // Functions//
    //////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price Feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAndpriceFeedAddressesMustBeSameLength();
        }

        // For example ETH/USD, BTC/USD, etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            sPriceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            sCollateralTokens.push(tokenAddresses[i]);
        }

        //stores the address of the DSC
        I_DSC = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////
    // External Functions//
    //////////////////////

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param tokenCollateralAddress The address of the token to deposit as collateral
    /// @param amountCollateral The amount of collateral to deposit
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        sCollateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /// @notice The function follows the CEI -> checks -> effects -> interactions
    /// @dev Explain to a developer any extra details
    /// @param amountDscToMint The amount of decentralized stablecoin to mint
    /// @notice they must have collateral value than the minimum threshold
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        sDscMinted[msg.sender] += amountDscToMint;
        _revertHealthFactorIsBroken(msg.sender); // to revert when user minted too much ($150,100ETH)

        // prevents a user to mint if he knows he/she will be liquidated
        bool minted = I_DSC.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintedFailed();
        }
    }

    /// @dev Explain to a developer any extra details
    /// @param tokenCollateralAddress The address of the token to deposit as collateral
    /// @param amountCollateral The amount of collateral to deposit
    /// @param amountDscToMint The amount of decentralized stablecoin to mint
    /// @notice this function will deposit your collateral and mint Dsc in one transaction
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    )
        external
    {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /// @param tokenAddress The collateral address to redeem
    /// @param amountCollateral The amount of collateral to redeem
    /// @param amountDScToBurn The amount of DSc to burn
    /// This function burns DSC and redeems underlying collateral in one transcation
    function redeemCollateralForDsc(
        address tokenAddress,
        uint256 amountCollateral,
        uint256 amountDScToBurn
    )
        external
    {
        _burnDsc(amountDScToBurn, msg.sender, msg.sender);
        _redeemCollateral(msg.sender, msg.sender, tokenAddress, amountCollateral);
    }

    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 amount) external moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        // we will figure out whether we need it
        _revertHealthFactorIsBroken(msg.sender);
    }

    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover
    )
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorWork();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        // whoever is calling the liquidate will get the bonus
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        // we need to burn the dsc
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        // prevents userhealthfactor from being ruined
        _revertHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external { }

    ///////////////////////////////////
    // Private and Internal Functions//
    //////////////////////////////////

    /// @dev Low-level internal function, call it only when checking for health factor
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        sDscMinted[onBehalfOf] -= amountDscToBurn;
        bool success = I_DSC.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        I_DSC.burn(amountDscToBurn);
    }

    function _redeemCollateral(
        address from,
        address to,
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        private
    {
        sCollateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = sDscMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user a parameter just like in doxygen (must be followed by parameter name)
    /// @return returns a uint256 value to determine liquidation
    function _healthFactor(address user) private view returns (uint256) {
        // total Dsc minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    // 1. Check health facotr (do they have enough collateral?)
    // 2. Revert if they don't
    function _revertHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    )
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedforThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedforThreshold * 1e18) / totalDscMinted;
    }

    ///////////////////////////////////
    // Public and External Functions//
    //////////////////////////////////
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(sPriceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return ((usdAmountInWei * PRECISION_FEED) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token,get the amount they have deposited, and map it to
        // the price, to get the USD value
        for (uint256 i = 0; i < sCollateralTokens.length; i++) {
            address token = sCollateralTokens[i];
            uint256 amount = sCollateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(sPriceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // 1ETH = $1000
        // The returned value from chainLink will be 1000 * 1e18
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION_FEED;
    }

    ///////////////////////////////////
    // Getter Functions             //
    //////////////////////////////////
    function getCollateralTokens() external view returns (address[] memory) {
        return sCollateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return sCollateralDeposited[user][token];
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 toalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function getPriceFeed(address token) external view returns (address) {
        return sPriceFeeds[token];
    }

    function getDSCAddress() external view returns (DecentralizedStableCoin) {
        return I_DSC;
    }

    function revertHealthFactorIsBroken(address user) external view {
        return _revertHealthFactorIsBroken(user);
    }

    function getPrecision() external pure returns (uint256){
        return PRECISION_FEED;
    }

    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd) external pure returns(uint256) {
            return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
        }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }    
}
