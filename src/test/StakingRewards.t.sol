// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "../StakingRewardsFactory.sol";
import "../StakingRewards.sol";
import "forge-std/console.sol";

contract StakingRewardsTest is Test {
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    Vm hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    StakingRewardsFactory public stakingRewardsFactory;
    StakingRewards public stakingRewards;
    address public stakingContract;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
    uint256 stakeAmount = 10e18;

    function deployStakingContract(
        address _stakingToken,
        uint256 _amount,
        uint256 _duration
    ) internal {
        hevm.warp(block.timestamp + 10);
        stakingRewardsFactory.deploy(_stakingToken, _amount, _duration);

        bool success = rewardToken.transfer(
            address(stakingRewardsFactory),
            _amount
        );
        if (success) {
            stakingRewardsFactory.notifyRewardAmounts();
        } else {
            revert("Transfer Failed");
        }

        (stakingContract, , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingToken));
    }

    function stakeToken(uint256 _stakeAmount) public {
        stakingToken.approve(stakingContract, _stakeAmount);
        StakingRewards(stakingContract).stake(_stakeAmount);
    }

    function setUp() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        rewardToken = new MockERC20("Token Test Reward", "TTR");
        stakingRewardsFactory = new StakingRewardsFactory(
            address(rewardToken),
            block.timestamp + 1
        );

        deployStakingContract(
            address(stakingToken),
            100e18,
            block.timestamp + 10 days
        );
    }

    function testStake() public {
        uint256 _stakeAmount = 1e18;
        stakingToken.approve(stakingContract, _stakeAmount);
        hevm.expectEmit(true, false, false, false);
        emit Staked(address(this), _stakeAmount);
        StakingRewards(stakingContract).stake(_stakeAmount);
    }

    function testCannotStakeZero() public {
        stakingToken.approve(stakingContract, 0);
        hevm.expectRevert(bytes("CSZ"));
        StakingRewards(stakingContract).stake(0);
    }

    function testMultipleStake() public {
        for (uint256 i = 1; i < 10; i++) {
            uint256 _stakeAmount = i * 1e18;
            stakingToken.approve(stakingContract, _stakeAmount);
            hevm.expectEmit(true, false, false, false);
            emit Staked(address(this), _stakeAmount);
            StakingRewards(stakingContract).stake(_stakeAmount);
        }
    }

    // Fuzz testing stake function
    function testStakeFuzz(uint128 _amount) public {
        stakingToken.approve(stakingContract, _amount);
        if (_amount > 0) {
            hevm.expectEmit(true, false, false, false);
            emit Staked(address(this), _amount);
            StakingRewards(stakingContract).stake(_amount);
        } else {
            hevm.expectRevert(bytes("CSZ"));
            StakingRewards(stakingContract).stake(_amount);
        }
    }

    // Withdraw Function
    function testCannotWithdrawZero() public {
        hevm.expectRevert(bytes("CWZ"));
        StakingRewards(stakingContract).withdraw(0);
    }

    function testWithdraw() public {
        stakeToken(10e18);
        hevm.expectEmit(true, false, false, false);
        uint256 withdrawAmount = StakingRewards(stakingContract).balanceOf(
            address(this)
        );
        emit Withdrawn(address(this), 10e18);
        StakingRewards(stakingContract).withdraw(withdrawAmount);
    }
}
