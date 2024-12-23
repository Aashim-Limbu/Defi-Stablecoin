// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
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
contract DSCEngine {
    constructor() { }
    function depositCollateralAndMintDSC()external {}
    function reedemCollateraAndBurnDSC()external {}
    function burnDSC()external {}
    function liquidate()external{}
    function getHealthFactor()external view{}
}
