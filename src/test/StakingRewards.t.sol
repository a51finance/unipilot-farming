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
    uint256 initialTime;

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

        (stakingContract, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingToken));
    }

    function stakeToken(uint256 _stakeAmount) public {
        stakingToken.approve(stakingContract, _stakeAmount);
        StakingRewards(stakingContract).stake(_stakeAmount);
    }

    function setUp() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        rewardToken = new MockERC20("Token Test Reward", "TTR");
        stakingRewardsFactory = new StakingRewardsFactory(block.timestamp + 1);
        initialTime = block.timestamp + 10 days;
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            initialTime
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

    // Total Supply

    function testTotalSupply() public {
        for (uint256 i = 1; i < 10; i++) {
            stakeToken(10e18);
        }
        uint256 totalSupply = StakingRewards(stakingContract).totalSupply();
        assertEq(totalSupply, 10e18 * 9);
    }

    function testValuesBeforeFirstStake() public {
        /**
         *  rewardRate = reward Amount / reward Duration
         *  rewardRate = 100e18 /  initialTime (initialTime is block.timestamp + 10 days)
         */
        assertEq(
            StakingRewards(stakingContract).rewardRate(),
            100e18 / initialTime
        );
        /**
         *  lastUpdateTime = block.timestamp
         */

        assertEq(
            StakingRewards(stakingContract).lastUpdateTime(),
            block.timestamp
        );
        /**
         *  Period Finish = block.timestamp + rewards Duration
         *  Period Finish = block.timestamp + initialTime
         */

        assertEq(
            StakingRewards(stakingContract).periodFinish(),
            block.timestamp + initialTime
        );

        /**
         *  Reward per token stored before stake
         */

        assertEq(StakingRewards(stakingContract).rewardPerTokenStored(), 0);

        /**
         *  Reward per token before stake will be 0 because totalSupply is 0
         */
        assertEq(
            StakingRewards(stakingContract).rewardPerToken(),
            StakingRewards(stakingContract).totalSupply()
        );
    }

    function testValuesFirstAfterStake() public {
        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);
        // Reward per token stored After stake
        // Since totalSupply is now greater than 0 we'll
        // calculate rewardPerToken

        uint256 _lastTimeRewardApplicable = Math.min(
            block.timestamp,
            StakingRewards(stakingContract).periodFinish()
        );
        uint256 rewardRate = 100e18 / initialTime;

        uint256 _lastUpdateTime = StakingRewards(stakingContract)
            .lastUpdateTime();

        // rewardPerTokenStored is equal to rewardPerToken Before the stake
        // it will be 0 ->
        // rewardPerTokenStored = 0

        uint256 _rewardPerToken = ((((0 +
            _lastTimeRewardApplicable -
            _lastUpdateTime) * rewardRate) * 1e18) / 10e18);

        assertEq(
            _rewardPerToken,
            StakingRewards(stakingContract).rewardPerToken()
        );
    }

    function testRewardPerTokenPaidAfterStakes() public {
        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);
        uint256 previousRewardPerToken = StakingRewards(stakingContract)
            .rewardPerToken();

        StakingRewards(stakingContract).getReward();
        stakeToken(10e18);
        stakeToken(20e18);
        hevm.warp(block.timestamp + 2 minutes);
        assertEq(
            previousRewardPerToken,
            StakingRewards(stakingContract).userRewardPerTokenPaid(
                address(this)
            )
        );
    }

    // reward Earned

    function testEarnedValue() public {
        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);

        // _balances[account] will return user's balance
        // _balances[account] = 10e18

        // userRewardPerTokenPaid will be 0
        // Since user hasn't claimed any reward yet
        // userRewardPerTokenPaid = 0

        // rewards[user] will be 0 since its first stake
        // rewards[user] = 0

        uint256 earnedBeforeRewardClaim = ((10e18 *
            StakingRewards(stakingContract).rewardPerToken()) / 1e18) + 0;

        assertEq(
            earnedBeforeRewardClaim,
            StakingRewards(stakingContract).earned(address(this))
        );

        // After claiming Reward
        uint256 previousRewardPerToken = StakingRewards(stakingContract)
            .rewardPerToken();

        StakingRewards(stakingContract).getReward();

        stakeToken(10e18);
        stakeToken(20e18);
        hevm.warp(block.timestamp + 2 minutes);

        uint256 earnedAfterStakesAndClaim = ((10e18 + 20e18 + 10e18) *
            (StakingRewards(stakingContract).rewardPerToken() -
                previousRewardPerToken)) /
            1e18 +
            0;

        assertEq(
            earnedAfterStakesAndClaim,
            StakingRewards(stakingContract).earned(address(this))
        );
    }

    function testGetReward() public {
        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);

        uint256 expectedReward = StakingRewards(stakingContract).earned(
            address(this)
        );
        uint256 _balanceBefore = rewardToken.balanceOf(address(this));
        StakingRewards(stakingContract).getReward();
        uint256 _balanceAfter = rewardToken.balanceOf(address(this));
        assertEq(expectedReward, _balanceAfter - _balanceBefore);
    }
}
