    // SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizationStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract OpenInvariantTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address weth;
    address wbtc;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (,, weth, wbtc,) = helperConfig.activeNetworkConfig();
        targetContract(address(dscEngine));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalDSCSupply = dsc.totalSupply();

        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

        uint256 wethUSDValue = dscEngine.getTokenUsdValue(weth, totalWethDeposited);
        uint256 wbtcUSDValue = dscEngine.getTokenUsdValue(wbtc, totalWbtcDeposited);

        assert(wethUSDValue + wbtcUSDValue >= totalDSCSupply);
    }
}
