// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../src/StakingRewardsFactory.sol";
import "../src/interfaces/IERC20.sol";

contract DeployStakingRewardsFactoryScript is Script {
    // Vm hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address rewardsToken = 0x4fC1263815Ab1E8fD97EC5010A7B4694dA6F593F;
    address stakingToken = 0xfBB9a726ed78631b7766E02f84cf2e40345D8083;
    uint256 stakingRewardsGenesis = block.timestamp + 1 minutes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PKEY");
        vm.startBroadcast(deployerPrivateKey);

        StakingRewardsFactory stakingRewardsFactory = new StakingRewardsFactory(
            stakingRewardsGenesis
        );

        IERC20(rewardsToken).transfer(address(stakingRewardsFactory), 100e18);

        // vm.stopBroadcast();

        // vm.startBroadcast(deployerPrivateKey);
        stakingRewardsFactory.deploy(
            stakingToken,
            rewardsToken,
            100e18,
            block.timestamp + 10 days
        );

        // stakingRewardsFactory.notifyRewardAmounts();
        vm.stopBroadcast();
    }
}
