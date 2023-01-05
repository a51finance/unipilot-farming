// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";
import "../src/StakingRewardsFactory.sol";

contract DeployStakingRewardsFactoryScript is Script {
    address rewardsToken = 0x4fC1263815Ab1E8fD97EC5010A7B4694dA6F593F;
    uint stakingRewardsGenesis = block.timestamp + 5 minutes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        StakingRewardsFactory stakingRewardsFactory = new StakingRewardsFactory(rewardsToken, stakingRewardsGenesis);

        vm.stopBroadcast();
    }
}

// contract DeployStakingRewardsScript is Script {
//     address rewardsToken = 0x4fC1263815Ab1E8fD97EC5010A7B4694dA6F593F;
//     uint stakingRewardsGenesis = 0;

//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//         StakingRewardsFactory stakingRewardsFactory = new StakingRewardsFactory(rewardsToken, stakingRewardsGenesis);

//         vm.stopBroadcast();
//     }
// }

// forge create --rpc-url https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161
// --private-key 4ef58c0f2dfe941a2c8c173ef3c98ea2f7575be2c7e67341e0e0b27464859dc7
//  src/StakingRewardsFactory.sol:StakingRewards
//   --constructor-args 0x97ff40b5678d2234b1e5c894b5f39b8ba8535431
//   0x4fC1263815Ab1E8fD97EC5010A7B4694dA6F593F
//   0xfBB9a726ed78631b7766E02f84cf2e40345D8083
//   --etherscan-api-key GSWUYPSZGBKJ168A2M78TF7VUA97AP6G22
//   --verify
