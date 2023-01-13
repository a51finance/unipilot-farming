// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../src/StakingRewardsFactory.sol";

contract DeployStakingRewardsFactoryScript is Script {
    address rewardsToken = 0x4fC1263815Ab1E8fD97EC5010A7B4694dA6F593F;
    uint256 stakingRewardsGenesis = block.timestamp + 1 minutes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        StakingRewardsFactory stakingRewardsFactory = new StakingRewardsFactory(
            stakingRewardsGenesis
        );
        vm.stopBroadcast();
    }
}
