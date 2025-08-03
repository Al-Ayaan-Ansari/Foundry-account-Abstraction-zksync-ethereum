// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";


contract HelperConfig is Script{

    error HelperConfig_invalidChain();
    
    struct NetConfig{
        address entryPoint;
        address account;
    }

    mapping(uint256 => NetConfig) public networkConfigs;
    NetConfig networkConfig;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    address constant BURNUR_ACCOUNT = 0x87A71F24501D61ece9e03d5b244e920103597eAd;
    // address constant FOUNDRY_DEFAULT_ACCOUNT = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    // Official Sepolia EntryPoint address: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    constructor(){
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSepoliaConfig();
        networkConfigs[LOCAL_CHAIN_ID] = getLocalAnvilConfig();
    }
    function getEthSepoliaConfig() internal pure returns (NetConfig memory) {
        // Official Sepolia EntryPoint address: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
        return NetConfig({entryPoint:0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,account:BURNUR_ACCOUNT});
    }
    
    function getZkSepoliaConfig() internal pure returns (NetConfig memory) {
        // Official Zksync sepolia EntryPoint is Address(0) due to being it nature account abstraction
        return NetConfig({entryPoint:address(0),account:BURNUR_ACCOUNT});
    }
    function getLocalAnvilConfig() internal returns (NetConfig memory) {
        if(networkConfig.account != address(0)){
            return networkConfig;
        }

        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        networkConfig = NetConfig({entryPoint:address(entryPoint),account:ANVIL_DEFAULT_ACCOUNT});
        return networkConfig;

    }
    function getHelperConfig() public view returns (NetConfig memory) {
        if(block.chainid != ETH_SEPOLIA_CHAIN_ID && block.chainid != ZKSYNC_SEPOLIA_CHAIN_ID && block.chainid != LOCAL_CHAIN_ID){
            revert HelperConfig_invalidChain();
        }


        return networkConfigs[block.chainid];
    }

    function run() public view {
        getHelperConfig();
    }

    
}