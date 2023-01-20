// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "../StakingRewardsFactory.sol";
import "../StakingRewards.sol";
import "forge-std/console.sol";

contract StakingRewardsFactoryTest is Test {
    event Deployed(
        address indexed stakingRewardContract,
        address stakingToken,
        address rewardToken,
        uint256 rewardAmount,
        uint256 rewardsDuration
    );

    Vm hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    StakingRewardsFactory public stakingRewardsFactory;
    StakingRewards public stakingRewards;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
    uint256 stakeAmount = 10e18;

    function deployStakingContract(
        address _stakingToken,
        address _rewardToken,
        uint256 _amount,
        uint256 _duration
    ) internal {
        hevm.warp(block.timestamp + 10);
        stakingRewardsFactory.deploy(
            _stakingToken,
            _rewardToken,
            _amount,
            _duration
        );

        bool success = rewardToken.transfer(
            address(stakingRewardsFactory),
            _amount
        );
        if (success) {
            stakingRewardsFactory.notifyRewardAmounts();
        } else {
            revert("Transfer Failed");
        }
    }

    function setUp() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        rewardToken = new MockERC20("Token Test Reward", "TTR");
        stakingRewardsFactory = new StakingRewardsFactory(block.timestamp + 1);
    }

    // Deploy function

    function testDeployStakingRewardsContract() public {
        hevm.warp(block.timestamp + 10);

        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
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

        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );

        hevm.expectRevert(bytes("AD"));
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );
    }

    function testCannotDeployWithInvalidAddress() public {
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );
        hevm.warp(block.timestamp + 10);
        hevm.expectRevert(bytes("IA"));
        deployStakingContract(
            address(0),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );

        hevm.warp(block.timestamp + 10);
        hevm.expectRevert(bytes("IA"));
        deployStakingContract(
            address(stakingToken),
            address(0),
            100e18,
            block.timestamp + 2 days
        );

        hevm.expectRevert(bytes("IA"));
        deployStakingContract(
            address(0),
            address(0),
            100e18,
            block.timestamp + 2 days
        );
    }

    // Update function

    function testUpdateStakingContract() public {
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );

        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        stakingRewardsFactory.update(
            address(stakingToken),
            100e18,
            futureDuration
        );
        (, , , uint256 duration) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingToken));
        assertEq(duration, futureDuration);
    }

    function testCannotUpdateStakingContract() public {
        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        hevm.expectRevert(bytes("UND"));
        stakingRewardsFactory.update(
            address(stakingToken),
            100e18,
            futureDuration
        );
    }

    // NotifyRewardAmounts function

    function testNotifyRewardAmount() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            10e18,
            block.timestamp + 2 days
        );
        stakingRewardsFactory.notifyRewardAmount(address(stakingToken));
    }

    function testNotifyRewardAmounts() public {
        for (uint256 i = 0; i < 5; i++) {
            stakingToken = new MockERC20("Token Test Staking", "TTS");
            deployStakingContract(
                address(stakingToken),
                address(rewardToken),
                10e18,
                block.timestamp + 2 days
            );
        }
        stakingRewardsFactory.notifyRewardAmounts();
    }

    function testCannotNotifyRewardAmounts() public {
        hevm.expectRevert(bytes("CBD"));
        stakingRewardsFactory.notifyRewardAmounts();
    }

    // notifyRewardAmount function
    function testCannotTestNotifyRewardAmount() public {
        stakingRewardsFactory.deploy(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );
        rewardToken.transfer(address(stakingRewardsFactory), 100e18);
        hevm.expectRevert(bytes("NNR"));
        stakingRewardsFactory.notifyRewardAmounts();
    }
}
