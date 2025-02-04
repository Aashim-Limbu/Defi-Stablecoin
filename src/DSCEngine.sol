// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {DecentralizedStableCoin} from "./DecentralizationStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) s_priceFeeds; //Token to PriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokenAddresses;

    DecentralizedStableCoin private immutable i_dsc;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDeposited(address indexed user, address indexed collateralAddress, uint256 indexed amount);
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
            s_priceFeeds[tokenAddress[i]] = priceFeedAddresses[i];
            s_collateralTokenAddresses.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDSC() external {}

    /**
     *
     * @param tokenCollateralAddress The address of the deposited token as collateral
     * @param amountCollateral The amount of token to be deposited
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
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
    function mintDSC(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender,amountDscToMint);
        if(!minted){
            revert DSCEngine__MintFailed();
        }
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThresold =
            (totalCollateralValueInUsd * LIQUIDATION_THRESOLD) / LIQUIDATION_PRECISION;
        //essentially reducing the collateral by 50% so that it always have higher collateral than the minted one.
        return (collateralAdjustedForThresold * PRECISION) / totalDscMinted;
    }

    function getHealthFactor() external view {}

    function reedemCollateraAndBurnDSC() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function redeemCollateral() external {}

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
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData(); // this is rounded to 1e8 to make it to wei 1e18 we multiply it with 1e10 just to make it 1e18
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / 1e18; //1e18 * 1e*18 so divide by 1e18
    }
}
