// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {DecentralizedStableCoin} from "./DecentralizationStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title DSC Engine
 * @author Aashim Limbu
 * The system is designed to be ps minimal as possible and have the tokento maintain 1 token = 1 USD peg.
 * This stablecoin has the properties:
 * 1. Collateral: Exogenous (ETH & BTC)
 * 2. Dollar Pegged
 * 3. Algorithmic Stable
 *
 * Our DSC system should always be "Over Collateralized" to prevent the system from becoming undercollateralized. At no point the value of all collateral should be less than the value of all DSC minted.
 * It is similar to DAI if DAI had no governance, no fees and was only bakced by WETH and WBTC.
 *
 * @notice This contract is the core of DSC System. It handles all the logic for minting and redeemin DSC , as well as depositiing and withdrawing collateral.
 * @notice This contract is very loosely based on MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DSCEngine__AmountMustBeGreaterThanZero();
    error DSCEngine__ContractInitializationError();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCENGINE__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__healthFactorGood();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine_DuplicateToken();
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) s_priceFeeds; //Token to PriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokenAddresses;

    DecentralizedStableCoin private immutable i_dsc;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDeposited(address indexed user, address indexed collateralAddress, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amountRedeemed
    );
    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__AmountMustBeGreaterThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address[] memory tokenAddress, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddress.length != priceFeedAddresses.length) {
            revert DSCEngine__ContractInitializationError();
        }
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            if (s_priceFeeds[tokenAddress[i]] != address(0)) revert DSCEngine_DuplicateToken();
            s_priceFeeds[tokenAddress[i]] = priceFeedAddresses[i];
            s_collateralTokenAddresses.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /**
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDSCToMint The amount of DSC to be minted
     * @notice This function will deposit your collateral and mint DSC in one transaction.
     */
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDSCToMint);
    }

    /**
     *
     * @param tokenCollateralAddress The address of the deposited token as collateral
     * @param amountCollateral The amount of token to be deposited
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        isAllowedToken(tokenCollateralAddress)
        moreThanZero(amountCollateral)
        nonReentrant
    {
        // i. update the s_collateral deposited
        // ii. transfer the the token to this contract
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     *
     * @param amountDscToMint The amount of DSC to be minted
     * @notice They must have collateral value more than the threshold
     */
    function mintDSC(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        // You don't need to check if the user redeemCollateral more than they have the solidity compiler simply won't let you do unsafe Math stuff.
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDSC(uint256 amountToBeBurnt) public moreThanZero(amountToBeBurnt) {
        _burnDSC(amountToBeBurnt, msg.sender, msg.sender);
    }

    function redeemCollateralAndBurnDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCToBurn
    ) external {
        burnDSC(amountDSCToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    //If we're nearing to undercollateralization, we need somebody to liquidate out position.
    //If someone is almost undercollateralized , we will pay you to liquidate them! .
    /**
     * @param collateralAddress The erc20 collateral address to liquidate from the victim.
     * @param victim user who has broken the health factor limit.
     * @param debtToCover The amount of DSC in USD you want to burn to improve the user health factor.
     * @notice Liquidator will get the bonus for taking the user funds.
     * @notice This protocol assumes its user to be always 200% overcollateralized in order for this to work.
     */
    function liquidate(address collateralAddress, address victim, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingHealthFactor = _healthFactor(victim);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__healthFactorGood();
        }
        uint256 totalCollateralAmountToBeCoveredForDebt = getTokenAmountFromUSD(collateralAddress, debtToCover);
        // Give Liquidator a 10% bonus.
        // so we're giving $110 of wETH for 100 DSC.
        // Should implement this feature to liquidate in the event the protocol is insolvent.
        // And Sweep extra amounts into a treasury.
        uint256 bonusCollateral = LIQUIDATION_BONUS * totalCollateralAmountToBeCoveredForDebt / LIQUIDATION_PRECISION;
        uint256 totalCollateralRedeem = totalCollateralAmountToBeCoveredForDebt + bonusCollateral;
        _redeemCollateral(collateralAddress, totalCollateralRedeem, victim, msg.sender);
        _burnDSC(debtToCover, victim, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(victim);
        console.log("Starting Health Factor: ", startingHealthFactor);
        console.log("Ending Health Factor: ", endingUserHealthFactor);
        if (endingUserHealthFactor <= startingHealthFactor) {
            // we actually don't imporve the health factor of victim hence, reverting ==> the debtToCover is not enough to improve the health factor.
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getTokenAmountFromUSD(address tokenAddress, uint256 debtUsdAmountInWei) public view returns (uint256) {
        //1. Get token price in USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //
        return (debtUsdAmountInWei * PRECISION / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }
    /*//////////////////////////////////////////////////////////////
                              I. FUNCTION
    //////////////////////////////////////////////////////////////*/
    /**
     * Returns how close a user is for liquidation.
     * If a user goes below 1, then they are liquid ated.
     */
    // 1. Check health factor ( do they have enought collateral ?)
    // 2. Revert if they don't revert

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCENGINE__BreaksHealthFactor(userHealthFactor);
        }
    }

    /**
     *
     * @dev Do not call this internal function unless the function that invoke this particular function has already checked the health factor.
     */
    //10 ether , vicitm , liquidator
    function _burnDSC(uint256 amountToBurn, address onBehalfOf, address dscFrom) internal {
        s_DSCMinted[onBehalfOf] -= amountToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountToBurn);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(user);
        if (totalDscMinted == 0) {
            return type(uint256).max;
        }
        uint256 collateralAdjustedForThresold =
            (totalCollateralValueInUsd * LIQUIDATION_THRESOLD) / LIQUIDATION_PRECISION;
        //essentially reducing the collateral by 50% so that it always have higher collateral than the minted one.
        return (collateralAdjustedForThresold * PRECISION) / totalDscMinted;
    }

    // from:victim to:liquidator
    function _redeemCollateral(address tokenAddress, uint256 amountCollateral, address from, address to) private {
        s_collateralDeposited[from][tokenAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenAddress, amountCollateral);
        bool success = IERC20(tokenAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     *
     * @param amountDSCMinted DSC Minted via a DSCEngine
     * @param amountCollateralDepositedInUSD Total value of Collateral in USD
     */
    function _calculateHealthFactor(uint256 amountDSCMinted, uint256 amountCollateralDepositedInUSD)
        private
        pure
        returns (uint256 healthFactor)
    {
        healthFactor = (amountCollateralDepositedInUSD * LIQUIDATION_THRESOLD * PRECISION)
            / (amountDSCMinted * LIQUIDATION_PRECISION);
    }

    function _getAccountInformation(address user)
        private
        view
        returns (
            uint256 totalDscMinted,
            uint256 totalCollateralValueInUsd //Total collateral value in USD
        )
    {
        totalDscMinted = s_DSCMinted[user];
        totalCollateralValueInUsd = getAccountCollateralValue(user);
    }

    /*//////////////////////////////////////////////////////////////
                   PUBLIC AND EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokenAddresses.length; i++) {
            address token = s_collateralTokenAddresses[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getTokenUsdValue(token, amount);
        }
    }

    function calculateHealthFactor(uint256 amountDSCMinted, uint256 amountCollateralDeposited)
        public
        pure
        returns (uint256 healthFactor)
    {
        healthFactor = _calculateHealthFactor(amountDSCMinted, amountCollateralDeposited);
    }

    function getTokenUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData(); // this is rounded to 1e8 to make it to wei 1e18 we multiply it with 1e10 just to make it 1e18
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / 1e18; //1e18 * 1e*18 so divide by 1e18 , since amount is also in terms of 1e18
    }

    function getCollateralBalanceOfUser(address user, address collateralType) public view returns (uint256) {
        return s_collateralDeposited[user][collateralType];
    }

    function getHealthFactor(address user) public view returns (uint256) {
        return _healthFactor(user);
    }

    function getAccountInformation() external view returns (uint256 totalDSCMinted, uint256 collateralValueInUSD) {
        return _getAccountInformation(msg.sender);
    }

    function getLiquidationPrecision() public pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getLiquidationBonus() public pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }
}
