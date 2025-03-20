// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizationStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;
    MockV3Aggregator ehtUsdPriceFeed;

    uint256 MAX_DEPOSIT_COLLATERAL = type(uint96).max;

    constructor(DecentralizedStableCoin _dsc, DSCEngine _dscEngine) {
        dsc = _dsc;
        dscEngine = _dscEngine;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ehtUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
    }

    function mintDSC(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        vm.startPrank(sender);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation();
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        vm.assume(maxDscToMint > 0);
        amount = bound(amount, 1, uint256(maxDscToMint));
        dscEngine.mintDSC(amount);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ehtUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_COLLATERAL);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxRedeemValue = dscEngine.getCollateralBalanceOfUser(address(collateral), msg.sender);
        vm.assume(maxRedeemValue > 0);
        amountCollateral = bound(amountCollateral, 1, maxRedeemValue);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
    }
    /*//////////////////////////////////////////////////////////////
                              PRIVATE VIEW
    //////////////////////////////////////////////////////////////*/

    function _getCollateralFromSeed(uint256 collaterlaSeed) private view returns (ERC20Mock) {
        if (collaterlaSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
