// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 < 0.9.0;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizationStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

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

    address public user = makeAddr("USER");
    uint256 constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
    }
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function testUsdPrice() public view {
        uint256 ethAmount = 10e18;
        uint256 expectedUSD = 30000e18;
        uint256 actualUSD = dscEngine.getUsdValue(weth, ethAmount); //10 ETH worth 30000 10 * 3000 ;
        assertEq(actualUSD, expectedUSD);
    }

    function testdepositCollateral() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), 10 ether);

        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
