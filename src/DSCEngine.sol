// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {DecentralizedStableCoin} from "./DecentralizationStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DSC Engine
 * @author Aashim Limbu
 * The system is designed to be as minimal as possible and have the tokento maintain 1 token = 1 USD peg.
 * This stablecoin has the properties:
 * 1. Collateral: Exogenous (ETH & BTC)
 * 2. Dollar Pegged
 * 3. Algorithmic Stable
 *
 * Our DSC system should always be "Over Collateralized" to prevent the system from becoming undercollateralized. At no point the value of all collaterala should be less than the value of all DSC minted.
 * It is similar to DAI if DAI had no governance, no fees and was only bakced by WETH and WBTC.
 *
 * @notice This contract is the core of DSC System. It handles all the logic for minting and redeemin DSC , as well as depositiing and withdrawing collateral.
 * @notice This contract is very loosly based on MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DSCEngine__AmountMustBeGreaterThanZero();
    error DSCEngine__ContractInitializationError();
    error DSCEngine__NotAllowedToken();
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address token => address priceFeed) s_priceFeeds; //Token to PriceFeed
    DecentralizedStableCoin private immutable i_dsc;
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
    constructor(
        address[] memory tokenAddress,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddress.length != priceFeedAddresses.length) {
            revert DSCEngine__ContractInitializationError();
        }
        for (uint i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddresses[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDSC() external {}

    /**
     *
     * @param tokenCollateralAddress The address of the deposited token as collateral
     * @param amountCollateral The amount of token to be deposited
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
        isAllowedToken(tokenCollateralAddress)
        moreThanZero(amountCollateral)
        nonReentrant
    {}

    function reedemCollateraAndBurnDSC() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function redeemCollateral() external {}

    function mintDSC() external {}

    function getHealthFactor() external view {}
}
