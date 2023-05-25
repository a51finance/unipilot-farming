// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../src/StakingRewardsFactory.sol";
import "../src/interfaces/IERC20.sol";

contract DeployStakingRewardsFactoryScript is Script {
    // Vm hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address rewardsToken = 0x1837d2285980853b0fe02AaD766a9403e311a4f4;
    address stakingToken = 0xE8f0E66906b4072dc4886aED005eC21D27B1a724;
    uint256 stakingRewardsGenesis = block.timestamp + 1 minutes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PKEY");
        vm.startBroadcast(deployerPrivateKey);

        StakingRewardsFactory stakingRewardsFactory = new StakingRewardsFactory(
            stakingRewardsGenesis
        );

        vm.stopBroadcast();
    }
}
