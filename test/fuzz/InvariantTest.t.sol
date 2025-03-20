    // SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0 <0.9.0;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizationStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract OpenInvariantTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (,, weth, wbtc,) = helperConfig.activeNetworkConfig();
        // targetContract(address(dscEngine));
        handler = new Handler(dsc, dscEngine);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveLargerValueThanSupply() public view {
        uint256 totalDSCSupply = dsc.totalSupply();

        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

        uint256 wethUSDValue = dscEngine.getTokenUsdValue(weth, totalWethDeposited);
        uint256 wbtcUSDValue = dscEngine.getTokenUsdValue(wbtc, totalWbtcDeposited);

        console.log("Times Minted", handler.timesMintIsCalled());

        assert(wethUSDValue + wbtcUSDValue >= totalDSCSupply);
    }

    function invariant_getterShouldNotRevert() public view {
        dscEngine.getLiquidationBonus();
        dscEngine.getLiquidationPrecision();
    }
}
