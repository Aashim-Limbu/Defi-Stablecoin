// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >= 0.8.0 <0.9.0;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "src/DecentralizationStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        vm.startBroadcast(deployerKey);
        //By default the test contract will be the deployer Address so, using private-key for account address
        address deployerAddress = vm.addr(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin(deployerAddress);
        DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dsc, dscEngine, helperConfig);
    }
}
