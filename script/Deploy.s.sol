// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { BatonFactory } from "../src/BatonFactory.sol";
import { BatonZapRouterV1 } from "../src/BatonZapRouterV1.sol";

import { Script } from "forge-std/Script.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address caviarFactoryAddress = vm.envAddress("CAVIAR_FACTORY");
        address wethAddress = vm.envAddress("WETH_TOKEN");
        address batonMonitor = vm.envAddress("BATON_MONITOR");

        vm.startBroadcast(deployerPrivateKey);

        //BatonFactory factory = new BatonFactory(payable(wethAddress), caviarFactoryAddress, batonMonitor);
        BatonZapRouterV1 zapRounter = new BatonZapRouterV1();

        vm.stopBroadcast();
    }
}
