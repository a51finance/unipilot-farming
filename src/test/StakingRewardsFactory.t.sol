// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "../StakingRewardsFactory.sol";

contract StakingRewardsFactoryTest is Test {
    StakingRewardsFactory public stakingRewardsFactory;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;

    function setUp() public {
        uint256 stakingRewardsGenesis = block.timestamp + 1 minutes;
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        rewardToken = new MockERC20("Token Test Reward", "TTR");
        stakingRewardsFactory = new StakingRewardsFactory(
            address(rewardToken),
            stakingRewardsGenesis
        );
    }

    function testRewardTokenAddress() public {
        assertEq(stakingRewardsFactory.rewardsToken(), address(rewardToken));
    }
}
