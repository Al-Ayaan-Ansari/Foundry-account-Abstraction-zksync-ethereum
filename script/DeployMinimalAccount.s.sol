// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";


contract DeployMinimalAccount is Script {
    function run() public {

    }
    function deployMinimalAccount() public returns(HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetConfig memory networkConfig = helperConfig.getHelperConfig();

        vm.startBroadcast(networkConfig.account);
        MinimalAccount minimalAccount = new MinimalAccount(networkConfig.entryPoint);
        minimalAccount.transferOwnership(networkConfig.account);
        vm.stopBroadcast();
        return (helperConfig, minimalAccount);
    }
}