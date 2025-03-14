// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 < 0.9.0;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizationStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20TransferMockFails} from "../mocks/ERC20TransferMockFail.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;

    address public USER = makeAddr("USER");
    uint256 constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 constant AMOUNT_TO_MINT = 15000 ether; // 1ether -> 3,000e18 USD // for 10 ether --> 30,000e18 USD
    uint256 constant AMOUNT_COLLATERAL = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }
    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthIsNotEqualToPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__ContractInitializationError.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function testUsdPrice() public view {
        uint256 ethAmount = 10e18;
        uint256 expectedUSD = 30000e18;
        uint256 actualUSD = dscEngine.getTokenUsdValue(weth, ethAmount); //10 ETH worth 30000 10 * 3000 ;
        assertEq(actualUSD, expectedUSD);
    }

    function testdepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), 10 ether);

        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testGetTokenAmountFromUSD() public view {
        uint256 usdAmount = 30000e18;
        uint256 expectedTokenAmount = 10e18;
        uint256 actualTokenAmount = dscEngine.getTokenAmountFromUSD(weth, usdAmount);
        assertEq(actualTokenAmount, expectedTokenAmount);
    }

    function testDepositCollateral() public {
        ERC20Mock randomAddressForCollateral = new ERC20Mock("Test", "T");
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(randomAddressForCollateral), 1 ether);
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositCollateralAndMintDSC() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        vm.prank(USER);
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = dscEngine.getAccountInformation();
        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedCollateralValueInUSD = dscEngine.getTokenUsdValue(weth, AMOUNT_COLLATERAL);
        assertEq(totalDSCMinted, expectedTotalDSCMinted);
        assertEq(collateralValueInUSD, expectedCollateralValueInUSD);
    }

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCalculateHealthFactor() public view {
        uint256 amountDepositedAsCollateral = 10 ether;
        uint256 amountOfDSCMinted = 5 ether;
        uint256 healthFactor = dscEngine.calculateHealthFactor(amountOfDSCMinted, amountDepositedAsCollateral);
        assertEq(healthFactor, 1e18);
    }

    function testRevertsIfMintedDSCBreakHealthFactor() public depositCollateral {
        vm.startPrank(USER);
        dscEngine.mintDSC(AMOUNT_TO_MINT);
        (uint256 totalDscMinted,) = dscEngine.getAccountInformation();
        assertEq(totalDscMinted, AMOUNT_TO_MINT);
        uint256 expectedHealthFactor = 5e17;
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCENGINE__BreaksHealthFactor.selector, expectedHealthFactor));
        dscEngine.mintDSC(AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositCollateral {
        vm.prank(USER);
        dscEngine.mintDSC(AMOUNT_TO_MINT);
        uint256 balance = dsc.balanceOf(USER);
        assertEq(balance, AMOUNT_TO_MINT);
    }
    /*//////////////////////////////////////////////////////////////
                                BURNDSC
    //////////////////////////////////////////////////////////////*/

    function testRevertsIfBurnAmountIsZero() public depositCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dscEngine.burnDSC(0);
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        dscEngine.burnDSC(1);
    }

    function testCanBurnDSC() public depositCollateralAndMintDSC {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT);
        dscEngine.burnDSC(AMOUNT_TO_MINT);

        vm.stopPrank();
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(0, userBalance);
    }
    /*//////////////////////////////////////////////////////////////
                         REDEEMCOLLATERAL TEST
    //////////////////////////////////////////////////////////////*/

    function testRevertsIfTransferFails() public {
        address owner = msg.sender;
        vm.startPrank(msg.sender);
        ERC20TransferMockFails dscMock = new ERC20TransferMockFails(owner); //weth version with intentionally transfer function failed
        tokenAddresses = [address(dscMock)];
        priceFeedAddresses = [wethUsdPriceFeed];
        DSCEngine mockDSCEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dscMock));
        dscMock.mint(USER, AMOUNT_TO_MINT);
        dscMock.transferOwnership(address(mockDSCEngine));
        vm.stopPrank();
        vm.startPrank(USER);
        ERC20Mock(address(dscMock)).approve(address(mockDSCEngine), AMOUNT_COLLATERAL);
        mockDSCEngine.depositCollateral(address(dscMock), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDSCEngine.redeemCollateral(address(dscMock), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositCollateral {
        vm.startPrank(USER);
        uint256 userBalanceBeforeRedeem = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceBeforeRedeem, AMOUNT_COLLATERAL);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userBalanceAfterRedeem = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceAfterRedeem, 0);
        vm.stopPrank();
    }
    /*//////////////////////////////////////////////////////////////
                      REDEEMCOLLATERALFORDSC TESTS
    //////////////////////////////////////////////////////////////*/

    function testMustRedeemMoreThanZero() public depositCollateralAndMintDSC {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dscEngine.redeemCollateralAndBurnDSC(weth, 0, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT);
        dscEngine.redeemCollateralAndBurnDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        uint256 actualCollateralValue = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(actualCollateralValue, 0);
        vm.stopPrank();
    }
    /*//////////////////////////////////////////////////////////////
                              HEALTHFACTOR
    //////////////////////////////////////////////////////////////*/

    function testHealthReportAccuracy() public {
        uint256 expectedHealthFactor = 30 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), 3 ether); //3 ether deposited
        dscEngine.depositCollateralAndMintDSC(weth, 3 ether, 150 ether); // 3 * $ 3,000 = $ 9,000 --> $ 9,000 X 0.5 = $ 4,500 => 4,500/150
        uint256 actualHealthFactor = dscEngine.getHealthFactor(USER);
        assertEq(expectedHealthFactor, actualHealthFactor);
        vm.stopPrank();
    }

    function testHealthFactorRevert() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        int256 ethUSDUpdatedPrice = 2000e8;
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(ethUSDUpdatedPrice);
        uint256 expectedHealthFactor = 666666666666666666;
        uint256 userHealthFactor = dscEngine.getHealthFactor(USER);
        assertEq(expectedHealthFactor, userHealthFactor);
    }

    /*//////////////////////////////////////////////////////////////
                              LIQUIDATION
    //////////////////////////////////////////////////////////////*/
    address LIQUIDATOR = makeAddr("LIQUIDATOR");
    uint256 collateralToCover = 1 ether;
    uint256 amountToMint = 100 ether;
    uint256 debtToCover = 10 ether;

    function testMustImproveHealthFactorOnLiquidation() public {
        address owner = msg.sender;
        MockMoreDebtDSC mockDSC = new MockMoreDebtDSC(owner, wethUsdPriceFeed);
        tokenAddresses = [weth];
        priceFeedAddresses = [wethUsdPriceFeed];

        vm.startPrank(owner);
        DSCEngine mockDSCEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDSC));
        mockDSC.transferOwnership(address(mockDSCEngine));
        vm.stopPrank();

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockDSCEngine), AMOUNT_COLLATERAL);
        mockDSCEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).mint(LIQUIDATOR, collateralToCover);
        ERC20Mock(weth).approve(address(mockDSCEngine), collateralToCover);
        mockDSCEngine.depositCollateralAndMintDSC(weth, collateralToCover, amountToMint);

        int256 ethUSDUpdatedPrice = 20e8;
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(ethUSDUpdatedPrice);

        mockDSC.approve(address(mockDSCEngine), debtToCover);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        mockDSCEngine.liquidate(weth, USER, debtToCover);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public depositCollateralAndMintDSC {
        //Deposit Collateral for Liquidator
        ERC20Mock(weth).mint(LIQUIDATOR, collateralToCover);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dscEngine), collateralToCover);
        dscEngine.depositCollateralAndMintDSC(weth, collateralToCover, amountToMint);
        dsc.approve(address(dscEngine), debtToCover);
        vm.stopPrank();
        vm.expectRevert(DSCEngine.DSCEngine__healthFactorGood.selector);
        dscEngine.liquidate(weth, USER, debtToCover);
    }

    // x * 2000 * 0.5 = $ 15,000 ; x = number of ETH to cover the debt
    uint256 collateralAmount = 15 ether;

    modifier liquidated() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        int256 updateEthUsdPrice = 2000e8;

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(updateEthUsdPrice);
        uint256 userHealthFactor = dscEngine.getHealthFactor(USER);
        // console.log("userHealthFactor", userHealthFactor);

        ERC20Mock(weth).mint(LIQUIDATOR, collateralAmount);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateralAndMintDSC(weth, collateralAmount, AMOUNT_TO_MINT);
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = dscEngine.getAccountInformation();
        // console.log("totalDSCMinted", totalDSCMinted);
        // console.log("collateralValue", collateralValueInUSD);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT);
        dscEngine.liquidate(weth, USER, AMOUNT_TO_MINT); //covering whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidateionPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(LIQUIDATOR);
        uint256 collateralObtained = dscEngine.getTokenAmountFromUSD(weth, AMOUNT_TO_MINT);
        uint256 totalCollateralObtained = collateralObtained
            + (collateralObtained * dscEngine.getLiquidationBonus()) / dscEngine.getLiquidationPrecision();
        uint256 hardCodedCollateralExpectation = 8_250_000_000_000_000_000; // 8.25 ether
        vm.prank(LIQUIDATOR);
        (, uint256 collateralValueInUSD) = dscEngine.getAccountInformation();
        assertEq(collateralValueInUSD, 30_000 ether); // (15 eth  * $2000) ether = 30_000 ether
        assertEq(hardCodedCollateralExpectation, totalCollateralObtained);
        assertEq(liquidatorWethBalance, totalCollateralObtained);
    }

    function testUserStillHasSomeCollateralLeftAfterLiquidation() public liquidated {
        uint256 collateralValue = dscEngine.getTokenAmountFromUSD(weth, AMOUNT_TO_MINT); //in ether
        console.log("collateralValue", collateralValue);
        uint256 liquidatorBonusCollateral =
            collateralValue + dscEngine.getLiquidationBonus() * collateralValue / dscEngine.getLiquidationPrecision();
        console.log("liquidatorBonusCollateral", liquidatorBonusCollateral);
        uint256 liquidatorBonusCollateralInUSD = dscEngine.getTokenUsdValue(weth, liquidatorBonusCollateral);
        console.log("liquidatorBonusCollateralInUSD", liquidatorBonusCollateralInUSD);
        uint256 expectedVictimLeftOverInUSD =
            dscEngine.getTokenUsdValue(weth, AMOUNT_COLLATERAL) - liquidatorBonusCollateralInUSD;
        console.log("expectedVictimLeftOverInUSD", expectedVictimLeftOverInUSD);
        vm.prank(USER);
        (, uint256 actualVictimLeftOverInUSD) = dscEngine.getAccountInformation();
        console.log(actualVictimLeftOverInUSD);
        assertEq(expectedVictimLeftOverInUSD, actualVictimLeftOverInUSD);
    }
}
