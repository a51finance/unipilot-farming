// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "../StakingRewardsFactory.sol";
import "../StakingRewards.sol";
import "forge-std/console.sol";

contract StakingRewardsFactoryTest is Test {
    Vm hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    StakingRewardsFactory public stakingRewardsFactory;
    StakingRewards public stakingRewards;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
    uint256 stakeAmount = 10e18;

    function setUp() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        rewardToken = new MockERC20("Token Test Reward", "TTR");
        stakingRewardsFactory = new StakingRewardsFactory(
            address(rewardToken),
            block.timestamp + 1
        );
    }

    function testRewardTokenAddress() public {
        assertEq(stakingRewardsFactory.rewardsToken(), address(rewardToken));
    }

    // Deploy function

    function testDeployStakingRewardsContract() public {
        hevm.warp(block.timestamp + 10);
        stakingRewardsFactory.deploy(
            address(stakingToken),
            100e18,
            block.timestamp + 2 days
        );

        bool success = rewardToken.transfer(
            address(stakingRewardsFactory),
            100e18
        );
        if (success) {
            stakingRewardsFactory.notifyRewardAmounts();
        } else {
            revert("Transfer Failed");
        }
    }

    function testCannotDeployWithZeroAddress() public {
        hevm.warp(block.timestamp + 10);
        stakingRewardsFactory.deploy(
            address(stakingToken),
            100e18,
            block.timestamp + 2 days
        );
        hevm.expectRevert(bytes("AD"));
        stakingRewardsFactory.deploy(
            address(stakingToken),
            100e18,
            block.timestamp + 2 days
        );
    }

    function testCannotDeployStakingRewardsContract() public {
        stakingRewardsFactory.deploy(
            address(stakingToken),
            100e18,
            block.timestamp + 2 days
        );
        rewardToken.transfer(address(stakingRewardsFactory), 100e18);
        hevm.expectRevert(bytes("NNR"));
        stakingRewardsFactory.notifyRewardAmounts();
    }
}
