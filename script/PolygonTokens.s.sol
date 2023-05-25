// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../src/test/ERC20.sol";

contract DeployMumbaiERC20 is Script {
    string name = "Reward Token A";
    string name2 = "Reward Token B";
    string symbol = "RTA";
    string symbol2 = "RTB";
    uint256 amount = 1000000000000000e18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PKEY");
        vm.startBroadcast(deployerPrivateKey);
        TokenContract tokenA = new TokenContract(amount, name, symbol);
        // TokenContract tokenB = new TokenContract(amount, name2, symbol2);
        vm.stopBroadcast();
    }
}
