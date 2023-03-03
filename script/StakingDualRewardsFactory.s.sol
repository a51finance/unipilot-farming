// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../src/StakingDualRewardsFactory.sol";
import "../src/interfaces/IERC20.sol";

contract DeployStakingDualRewardsFactoryScript is Script {
    // Vm hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address rewardsTokenA = 0x1837d2285980853b0fe02AaD766a9403e311a4f4;
    address rewardsTokenB = 0xd056Deaa25C6D5C7A93D5EAC37Bb78b5265D2e15;
    address stakingToken = 0xA28Bc45f9C3D8741f4020313E142da998F20CC90;
    uint256 stakingRewardsGenesis = block.timestamp + 1 minutes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PKEY");
        vm.startBroadcast(deployerPrivateKey);

        StakingDualRewardsFactory stakingDualRewardsFactory = new StakingDualRewardsFactory(
                stakingRewardsGenesis
            );
        vm.stopBroadcast();
    }
}
