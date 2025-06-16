// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Funderr} from "../src/Funderr.sol";

// TODO: Add helper config to be able to deploy to different networks and use different constructor parameters

contract DeployFunderr is Script {
    function run() external returns (Funderr) {
        vm.startBroadcast();
        Funderr funderr = new Funderr(100, 2000, 30 days, 0.005 ether);
        vm.stopBroadcast();

        return funderr;
    }
}
