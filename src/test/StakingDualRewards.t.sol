// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockERC20Permit.sol";
import "../StakingDualRewardsFactory.sol";
import "../StakingDualRewards.sol";
import "forge-std/console.sol";

contract StakingDualRewardsTest is Test {
    event RewardAdded(uint256 rewardA, uint256 rewardB, uint256 periodFinish);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, address rewardToken, uint256 reward);
    event Recovered(address token, uint256 amount);

    Vm hevm = Vm(HEVM_ADDRESS);
    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    StakingDualRewardsFactory public stakingDualRewardsFactory;
    address public stakingDualRewards;
    MockERC20 public stakingToken;
    MockERC20 public rewardTokenA;
    MockERC20 public rewardTokenB;
    MockERC20Permit tokenPermit;
    uint256 stakeAmount = 10e18;
    uint256 initialTime;
    uint256 internal ownerPrivateKey;

    // addresses

    address alice = hevm.addr(1);
    address bob = hevm.addr(2);
    address user1 = hevm.addr(3);
    address user2 = hevm.addr(4);

    function deployStakingContract(
        address _stakingToken,
        address _rewardTokenA,
        address _rewardTokenB,
        uint256 _rewardAmountA,
        uint256 _rewardAmountB,
        uint256 _duration
    ) internal {
        hevm.warp(block.timestamp + 1 minutes);

        stakingDualRewardsFactory.deploy(
            _stakingToken,
            _rewardTokenA,
            _rewardTokenB,
            _rewardAmountA,
            _rewardAmountB,
            _duration
        );

        (stakingDualRewards, , , , , ) = stakingDualRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingToken));

        bool success1 = rewardTokenA.transfer(
            address(stakingDualRewardsFactory),
            _rewardAmountA
        );

        bool success2 = rewardTokenB.transfer(
            address(stakingDualRewardsFactory),
            _rewardAmountB
        );

        if (success1 && success2) {
            stakingDualRewardsFactory.notifyRewardAmounts();
        } else {
            revert("Transfer Failed");
        }
    }

    function stakeToken(uint256 _stakeAmount) public {
        stakingToken.approve(stakingDualRewards, _stakeAmount);
        StakingDualRewards(stakingDualRewards).stake(_stakeAmount);
    }

    function setUp() public {
        stakingToken = new MockERC20("StakingToken", "ST");
        rewardTokenA = new MockERC20("RewardTokenA", "RTA");
        rewardTokenB = new MockERC20("RewardTokenB", "RTB");
        initialTime = (30 * 24 * 60 * 60);
        stakingDualRewardsFactory = new StakingDualRewardsFactory(
            block.timestamp + 1 minutes
        );
        deployStakingContract(
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            100e18,
            150e18,
            initialTime
        );
    }

    function testStake() public {
        uint256 _stakeAmount = 1e18;
        stakingToken.approve(stakingDualRewards, _stakeAmount);
        hevm.expectEmit(true, false, false, false);
        emit Staked(address(this), _stakeAmount);
        StakingDualRewards(stakingDualRewards).stake(_stakeAmount);
        hevm.warp(block.timestamp + 2 days);
    }

    function testCannotStakeZero() public {
        stakingToken.approve(stakingDualRewards, 0);
        hevm.expectRevert(bytes("CSZ"));
        StakingDualRewards(stakingDualRewards).stake(0);
    }

    function testMultipleStake() public {
        for (uint256 i = 1; i < 10; i++) {
            uint256 _stakeAmount = i * 1e18;
            stakingToken.approve(stakingDualRewards, _stakeAmount);
            hevm.expectEmit(true, false, false, false);
            emit Staked(address(this), _stakeAmount);
            StakingDualRewards(stakingDualRewards).stake(_stakeAmount);
        }
    }

    function testStakeWithoutNotifying() public {
        uint256 _stakeAmount = 10e18;
        bool _rewardA;
        bool _rewardB;
        MockERC20 stakingTokenTest = new MockERC20("Token  Staking", "TS");

        // deploy staking vault
        stakingDualRewardsFactory.deploy(
            address(stakingTokenTest),
            address(rewardTokenA),
            address(rewardTokenB),
            10e18,
            20e18,
            initialTime
        );

        (stakingDualRewards, , , , , ) = stakingDualRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingTokenTest));
        // approve tokens

        stakingTokenTest.approve(stakingDualRewards, _stakeAmount);

        // stake

        StakingDualRewards(stakingDualRewards).stake(_stakeAmount);

        // fast forward 10 mins

        hevm.warp(block.timestamp + 10 minutes);

        assertEq(
            0,
            StakingDualRewards(stakingDualRewards).earnedA(address(this))
        );

        assertEq(
            0,
            StakingDualRewards(stakingDualRewards).earnedB(address(this))
        );

        // Transfer tokens to factory and run notify

        bool success = rewardTokenA.transfer(
            address(stakingDualRewardsFactory),
            10e18
        );

        success = rewardTokenB.transfer(
            address(stakingDualRewardsFactory),
            20e18
        );

        if (success) {
            stakingDualRewardsFactory.notifyRewardAmounts();
        } else {
            revert("Transfer Failed");
        }

        // fast forward 10 mins

        hevm.warp(block.timestamp + 10 minutes);

        // Check reward Again
        _rewardA =
            StakingDualRewards(stakingDualRewards).earnedA(address(this)) > 0;
        _rewardB =
            StakingDualRewards(stakingDualRewards).earnedB(address(this)) > 0;

        assertEq(_rewardA, true);
        assertEq(_rewardB, true);
    }

    function testStakeFuzz(uint128 _amount) public {
        stakingToken.approve(stakingDualRewards, _amount);
        if (_amount > 0) {
            hevm.expectEmit(true, false, false, false);
            emit Staked(address(this), _amount);
            StakingDualRewards(stakingDualRewards).stake(_amount);
        } else {
            hevm.expectRevert(bytes("CSZ"));
            StakingDualRewards(stakingDualRewards).stake(_amount);
        }
    }

    // Withdraw Function
    function testCannotWithdrawZero() public {
        hevm.expectRevert(bytes("CWZ"));
        StakingDualRewards(stakingDualRewards).withdraw(0);
    }

    function testWithdraw() public {
        stakeToken(10e18);
        hevm.expectEmit(true, false, false, false);
        uint256 withdrawAmount = StakingDualRewards(stakingDualRewards)
            .balanceOf(address(this));
        emit Withdrawn(address(this), 10e18);
        StakingDualRewards(stakingDualRewards).withdraw(withdrawAmount);
    }

    // other functions

    function testTotalSupply() public {
        for (uint256 i = 1; i < 10; i++) {
            stakeToken(10e18);
        }
        uint256 totalSupply = StakingDualRewards(stakingDualRewards)
            .totalSupply();
        assertEq(totalSupply, 10e18 * 9);
    }

    function testValuesBeforeFirstStake() public {
        /**
         *  rewardRate = reward Amount / reward Duration
         *  rewardRate = 100e18 /  initialTime (initialTime is block.timestamp + 10 days)
         */
        assertEq(
            StakingDualRewards(stakingDualRewards).rewardRateA(),
            100e18 / initialTime
        );

        assertEq(
            StakingDualRewards(stakingDualRewards).rewardRateB(),
            150e18 / initialTime
        );

        /**
         *  lastUpdateTime = block.timestamp
         */

        assertEq(
            StakingDualRewards(stakingDualRewards).lastUpdateTime(),
            block.timestamp
        );

        /**
         *  Period Finish = block.timestamp + rewards Duration
         *  Period Finish = block.timestamp + initialTime
         */

        assertEq(
            StakingDualRewards(stakingDualRewards).periodFinish(),
            block.timestamp + initialTime
        );

        /**
         *  Reward per token stored before stake
         */

        assertEq(
            StakingDualRewards(stakingDualRewards).rewardPerTokenAStored(),
            0
        );
        assertEq(
            StakingDualRewards(stakingDualRewards).rewardPerTokenBStored(),
            0
        );

        /**
         *  Reward per token before stake will be 0 because totalSupply is 0
         */
        assertEq(
            StakingDualRewards(stakingDualRewards).rewardPerTokenA(),
            StakingDualRewards(stakingDualRewards).totalSupply()
        );

        assertEq(
            StakingDualRewards(stakingDualRewards).rewardPerTokenB(),
            StakingDualRewards(stakingDualRewards).totalSupply()
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
            StakingDualRewards(stakingDualRewards).periodFinish()
        );
        uint256 rewardRateA = 100e18 / initialTime;
        uint256 rewardRateB = 150e18 / initialTime;

        uint256 _lastUpdateTime = StakingDualRewards(stakingDualRewards)
            .lastUpdateTime();

        // rewardPerTokenStored is equal to rewardPerToken Before the stake
        // it will be 0 ->
        // rewardPerTokenStoredA = 0
        // rewardPerTokenStoredB = 0

        uint256 _rewardPerTokenA = ((((0 +
            _lastTimeRewardApplicable -
            _lastUpdateTime) * rewardRateA) * 1e18) / 10e18);

        uint256 _rewardPerTokenB = ((((0 +
            _lastTimeRewardApplicable -
            _lastUpdateTime) * rewardRateB) * 1e18) / 10e18);

        assertEq(
            _rewardPerTokenA,
            StakingDualRewards(stakingDualRewards).rewardPerTokenA()
        );
        assertEq(
            _rewardPerTokenB,
            StakingDualRewards(stakingDualRewards).rewardPerTokenB()
        );
    }

    function testRewardPerTokenPaidAfterStakes() public {
        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);
        uint256 previousRewardPerTokenA = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenA();

        uint256 previousRewardPerTokenB = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenB();

        StakingDualRewards(stakingDualRewards).getReward();
        stakeToken(10e18);
        stakeToken(20e18);
        hevm.warp(block.timestamp + 2 minutes);
        assertEq(
            previousRewardPerTokenA,
            StakingDualRewards(stakingDualRewards).userRewardPerTokenAPaid(
                address(this)
            )
        );

        assertEq(
            previousRewardPerTokenB,
            StakingDualRewards(stakingDualRewards).userRewardPerTokenBPaid(
                address(this)
            )
        );
    }

    // reward Earned

    function testEarnedValue() public {
        /**
         * _balances[account] will return user's balance
         * _balances[account] = 10e18
         * userRewardPerTokenPaid will be 0
         * Since user hasn't claimed any reward yet
         * userRewardPerTokenPaid = 0
         * rewards[user] will be 0 since its first stake
         * rewards[user] = 0
         */

        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);

        uint256 earnedABeforeRewardClaim = ((10e18 *
            StakingDualRewards(stakingDualRewards).rewardPerTokenA()) / 1e18) +
            0;

        assertEq(
            earnedABeforeRewardClaim,
            StakingDualRewards(stakingDualRewards).earnedA(address(this))
        );

        uint256 earnedBBeforeRewardClaim = ((10e18 *
            StakingDualRewards(stakingDualRewards).rewardPerTokenB()) / 1e18) +
            0;

        assertEq(
            earnedBBeforeRewardClaim,
            StakingDualRewards(stakingDualRewards).earnedB(address(this))
        );

        // After claiming Reward
        uint256 previousRewardPerTokenA = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenA();

        uint256 previousRewardPerTokenB = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenB();

        StakingDualRewards(stakingDualRewards).getReward();

        stakeToken(10e18);
        stakeToken(20e18);
        hevm.warp(block.timestamp + 2 minutes);

        uint256 earnedAAfterStakesAndClaim = ((10e18 + 20e18 + 10e18) *
            (StakingDualRewards(stakingDualRewards).rewardPerTokenA() -
                previousRewardPerTokenA)) /
            1e18 +
            0;

        uint256 earnedBAfterStakesAndClaim = ((10e18 + 20e18 + 10e18) *
            (StakingDualRewards(stakingDualRewards).rewardPerTokenB() -
                previousRewardPerTokenB)) /
            1e18 +
            0;

        assertEq(
            earnedAAfterStakesAndClaim,
            StakingDualRewards(stakingDualRewards).earnedA(address(this))
        );

        assertEq(
            earnedBAfterStakesAndClaim,
            StakingDualRewards(stakingDualRewards).earnedB(address(this))
        );
    }

    function testGetReward() public {
        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);

        uint256 expectedRewardA = StakingDualRewards(stakingDualRewards)
            .earnedA(address(this));

        uint256 expectedRewardB = StakingDualRewards(stakingDualRewards)
            .earnedB(address(this));

        uint256 _balanceBeforeA = rewardTokenA.balanceOf(address(this));
        uint256 _balanceBeforeB = rewardTokenB.balanceOf(address(this));

        StakingDualRewards(stakingDualRewards).getReward();

        uint256 _balanceAfterA = rewardTokenA.balanceOf(address(this));
        uint256 _balanceAfterB = rewardTokenB.balanceOf(address(this));

        assertEq(expectedRewardA, _balanceAfterA - _balanceBeforeA);
        assertEq(expectedRewardB, _balanceAfterB - _balanceBeforeB);
    }

    function testEarnedValueWithMultipleUsers() public {
        stakingToken.transfer(alice, 10000e18);
        stakingToken.transfer(bob, 10000e18);
        uint256 aliceEarnedA;
        uint256 aliceEarnedB;
        uint256 bobEarnedA;
        uint256 bobEarnedB;

        stakeToken(15e18);

        uint256 user1EarnedA = 15e18 *
            ((StakingDualRewards(stakingDualRewards).rewardPerTokenA() - 0) /
                1e18) +
            0;

        uint256 user1EarnedB = 15e18 *
            ((StakingDualRewards(stakingDualRewards).rewardPerTokenB() - 0) /
                1e18) +
            0;
        assertEq(
            user1EarnedA,
            StakingDualRewards(stakingDualRewards).earnedA(address(this))
        );

        assertEq(
            user1EarnedB,
            StakingDualRewards(stakingDualRewards).earnedB(address(this))
        );

        // alice

        hevm.startPrank(alice);

        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);

        aliceEarnedA =
            (10e18 *
                (StakingDualRewards(stakingDualRewards).rewardPerTokenA() -
                    0)) /
            1e18;

        aliceEarnedB =
            (10e18 *
                (StakingDualRewards(stakingDualRewards).rewardPerTokenB() -
                    0)) /
            1e18;

        assertEq(
            aliceEarnedA,
            StakingDualRewards(stakingDualRewards).earnedA(address(alice))
        );

        assertEq(
            aliceEarnedB,
            StakingDualRewards(stakingDualRewards).earnedB(address(alice))
        );

        uint256 previousRewardA = aliceEarnedA;
        uint256 previousRewardB = aliceEarnedB;

        StakingDualRewards(stakingDualRewards).getReward();
        assertEq(rewardTokenA.balanceOf(alice), aliceEarnedA);
        assertEq(rewardTokenB.balanceOf(alice), aliceEarnedB);

        previousRewardA = 0;
        previousRewardB = 0;

        uint256 previousRewardPerTokenA = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenA();

        uint256 previousRewardPerTokenB = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenB();

        assertEq(
            previousRewardPerTokenA,
            StakingDualRewards(stakingDualRewards).userRewardPerTokenAPaid(
                alice
            )
        );

        assertEq(
            previousRewardPerTokenB,
            StakingDualRewards(stakingDualRewards).userRewardPerTokenBPaid(
                alice
            )
        );

        uint256 balance = StakingDualRewards(stakingDualRewards).balanceOf(
            alice
        );

        uint256 previouslyEarnedA = (balance *
            (StakingDualRewards(stakingDualRewards).rewardPerTokenA() -
                previousRewardPerTokenA)) / 1e18;

        uint256 previouslyEarnedB = (balance *
            (StakingDualRewards(stakingDualRewards).rewardPerTokenB() -
                previousRewardPerTokenB)) / 1e18;

        stakeToken(25e18);

        hevm.warp(block.timestamp + 2 minutes);

        previouslyEarnedA = StakingDualRewards(stakingDualRewards).earnedA(
            alice
        );
        previousRewardPerTokenA = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenA();

        previouslyEarnedB = StakingDualRewards(stakingDualRewards).earnedB(
            alice
        );
        previousRewardPerTokenB = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenB();

        previousRewardA = previouslyEarnedA;
        previousRewardB = previouslyEarnedB;

        stakeToken(45e18);

        hevm.warp(block.timestamp + 5 minutes);
        balance = StakingDualRewards(stakingDualRewards).balanceOf(alice);

        aliceEarnedA =
            ((balance *
                (StakingDualRewards(stakingDualRewards).rewardPerTokenA() -
                    previousRewardPerTokenA)) / 1e18) +
            previousRewardA;

        aliceEarnedB =
            ((balance *
                (StakingDualRewards(stakingDualRewards).rewardPerTokenB() -
                    previousRewardPerTokenB)) / 1e18) +
            previousRewardB;

        assertEq(
            aliceEarnedA,
            StakingDualRewards(stakingDualRewards).earnedA(address(alice))
        );

        assertEq(
            aliceEarnedB,
            StakingDualRewards(stakingDualRewards).earnedB(address(alice))
        );

        hevm.stopPrank();

        // bob

        hevm.startPrank(bob);
        previousRewardPerTokenA = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenA();
        previousRewardA = 0;

        previousRewardPerTokenB = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenB();
        previousRewardB = 0;

        stakeToken(300e18);
        balance = StakingDualRewards(stakingDualRewards).balanceOf(bob);
        bobEarnedA =
            balance *
            ((StakingDualRewards(stakingDualRewards).rewardPerTokenA() - 0) /
                1e18) +
            0;

        bobEarnedB =
            balance *
            ((StakingDualRewards(stakingDualRewards).rewardPerTokenB() - 0) /
                1e18) +
            0;

        assertEq(
            bobEarnedA,
            StakingDualRewards(stakingDualRewards).earnedA(address(bob))
        );

        assertEq(
            bobEarnedB,
            StakingDualRewards(stakingDualRewards).earnedB(address(bob))
        );

        hevm.stopPrank();

        hevm.warp(block.timestamp + 1 minutes);
    }

    function testExitFunction() public {
        stakingToken.transfer(user2, 200e18);

        hevm.startPrank(user2);

        stakeToken(200e18);

        hevm.warp(block.timestamp + 10 minutes);

        uint256 rewardA = StakingDualRewards(stakingDualRewards).earnedA(
            address(user2)
        );
        uint256 rewardB = StakingDualRewards(stakingDualRewards).earnedB(
            address(user2)
        );

        StakingDualRewards(stakingDualRewards).exit();

        uint256 finalOutPutA = stakingToken.balanceOf(address(user2)) +
            rewardTokenA.balanceOf(address(user2));

        uint256 finalOutPutB = stakingToken.balanceOf(address(user2)) +
            rewardTokenB.balanceOf(address(user2));

        uint256 expectedOutPutA = rewardA + 200e18;
        uint256 expectedOutPutB = rewardB + 200e18;

        assertEq(finalOutPutA, expectedOutPutA);
        assertEq(finalOutPutB, expectedOutPutB);

        assertEq(
            StakingDualRewards(stakingDualRewards).balanceOf(address(user2)),
            0
        );

        hevm.stopPrank();
    }

    // Notify Reward Amount
    function testCannotPassRequireChecksNotifyRewardAmount() public {
        stakingDualRewardsFactory = new StakingDualRewardsFactory(
            block.timestamp + 1
        );
        uint256 iTime = block.timestamp + 10 days;
        deployStakingContract(
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            100e18,
            150e18,
            iTime
        );

        // reducing existing period

        hevm.expectRevert(bytes("CRP"));
        hevm.prank(address(stakingDualRewardsFactory));
        StakingDualRewards(stakingDualRewards).notifyRewardAmount(
            20e18,
            15e18,
            block.timestamp + 2 days
        );
        uint256 _periodFinish = 0;
        uint256 _rewardRateA = 0;
        uint256 _rewardRateB = 0;
        if (block.timestamp >= _periodFinish) {
            _rewardRateA = 100e18 / iTime;
            _rewardRateB = 150e18 / iTime;
            assertEq(
                _rewardRateA,
                StakingDualRewards(stakingDualRewards).rewardRateA()
            );
            assertEq(
                _rewardRateB,
                StakingDualRewards(stakingDualRewards).rewardRateB()
            );
        }

        // Providing too high reward

        hevm.warp(block.timestamp + 7 days);
        uint256 newDuration = block.timestamp + 5 days;
        hevm.expectRevert(bytes("RATH"));
        hevm.prank(address(stakingDualRewardsFactory));
        StakingDualRewards(stakingDualRewards).notifyRewardAmount(
            2000000e18,
            1500000e18,
            newDuration
        );

        hevm.expectRevert(bytes("RBTH"));
        hevm.prank(address(stakingDualRewardsFactory));
        StakingDualRewards(stakingDualRewards).notifyRewardAmount(
            0,
            1500000e18,
            newDuration
        );
    }

    // function testNotifyingSinlgeTokenReward() public {
    //     stakingDualRewardsFactory = new StakingDualRewardsFactory(
    //         block.timestamp + 1
    //     );
    //     uint256 iTime = block.timestamp + 10 days;
    //     deployStakingContract(
    //         address(stakingToken),
    //         address(rewardTokenA),
    //         address(rewardTokenB),
    //         10000e18,
    //         15000e18,
    //         iTime
    //     );

    //     hevm.warp(iTime);

    //     uint256 newDuration = block.timestamp + 100 days;
    //     // uint256 newAmountA = 150e18;
    //     // uint256 newAmountB = 250e18;

    //     // uint256 balanceA = rewardTokenA.balanceOf(address(stakingDualRewards));
    //     // uint256 balanceB = rewardTokenB.balanceOf(address(stakingDualRewards));

    //     // uint256 rewardRateA = newAmountA / newDuration;
    //     // uint256 rewardRateB = newAmountB / newDuration;

    //     // console.log(rewardRateA, balanceA / newDuration);
    //     // console.log(rewardRateB, balanceB / newDuration);

    //     // console.log(rewardRateA <= balanceA / newDuration);
    //     // console.log(rewardRateB <= balanceB / newDuration);

    //     rewardTokenA.transfer(address(stakingDualRewardsFactory), 1000e18);
    //     // rewardB.transfer()
    //     hevm.prank(address(stakingDualRewardsFactory));
    //     StakingDualRewards(stakingDualRewards).notifyRewardAmount(
    //         200e18,
    //         0,
    //         newDuration
    //     );
    //     hevm.warp(newDuration);
    //     newDuration = block.timestamp + 10 days;
    //     rewardTokenB.transfer(address(stakingDualRewardsFactory), 1000e18);
    //     hevm.prank(address(stakingDualRewardsFactory));
    //     StakingDualRewards(stakingDualRewards).notifyRewardAmount(
    //         0,
    //         200e18,
    //         newDuration
    //     );
    // }

    // recoverERC20
    function testRecoverERC20() public {
        MockERC20 testToken = new MockERC20("StakingTokenTest", "STT");
        uint256 stakedAmount = 50e18;
        stakeToken(stakedAmount);
        testToken.transfer(address(stakingDualRewards), 10000e18);

        StakingDualRewards(stakingDualRewards).recoverERC20(
            address(testToken),
            10000e18 / 2
        );

        assertEq(
            testToken.balanceOf(address(stakingDualRewards)),
            10000e18 / 2
        );

        hevm.expectRevert(bytes("CWT"));
        StakingDualRewards(stakingDualRewards).recoverERC20(
            address(stakingToken),
            stakedAmount
        );
        uint256 contractBalanceBefore = rewardTokenA.balanceOf(
            address(stakingDualRewards)
        );
        StakingDualRewards(stakingDualRewards).recoverERC20(
            address(rewardTokenA),
            stakedAmount
        );

        assertEq(
            rewardTokenA.balanceOf(address(stakingDualRewards)),
            contractBalanceBefore - stakedAmount
        );
    }

    // function testStakingScenario() public {
    //     MockERC20 testToken1 = new MockERC20("StakingTokenTest", "STT");

    //     stakingDualRewardsFactory.deploy(
    //         address(this),
    //         address(testToken1),
    //         address(rewardTokenA),
    //         address(rewardTokenB),
    //         90500000000000000000,
    //         90500000000000000000,
    //         2 days
    //     );

    //     (stakingDualRewards, , , , , ) = stakingDualRewardsFactory
    //         .stakingRewardsInfoByStakingToken(address(testToken1));
    //     uint256 _stakeAmount = 200e18;
    //     testToken1.transfer(bob, 10000e18);

    //     // Approve and stake
    //     hevm.prank(bob);
    //     testToken1.approve(stakingDualRewards, _stakeAmount);
    //     hevm.prank(bob);
    //     StakingDualRewards(stakingDualRewards).stake(_stakeAmount);

    //     // hevm.warp(block.timestamp + 60);

    //     bool success1 = rewardTokenA.transfer(
    //         address(stakingDualRewardsFactory),
    //         90500000000000000000
    //     );

    //     //    / hevm.warp(block.timestamp + 60);

    //     bool success2 = rewardTokenB.transfer(
    //         address(stakingDualRewardsFactory),
    //         90500000000000000000
    //     );

    //     // hevm.warp(block.timestamp + 60);

    //     stakingDualRewardsFactory.notifyRewardAmount(address(testToken1));

    //     console.log(
    //         "Balance -> ",
    //         rewardTokenA.balanceOf(address(stakingDualRewards))
    //     );

    //     hevm.warp(block.timestamp + 2 days);

    //     hevm.prank(bob);
    //     StakingDualRewards(stakingDualRewards).getReward();

    //     console.log("Bob Balance -> ", rewardTokenA.balanceOf(address(bob)));

    //     assertEq(rewardTokenA.balanceOf(address(stakingDualRewards)), 0);
    // }

    function testRewardEarningMechanism() public {
        MockERC20 testToken1 = new MockERC20("StakingTokenTest", "STT");

        stakingDualRewardsFactory.deploy(
            address(testToken1),
            address(rewardTokenA),
            address(rewardTokenB),
            90500000000000000000,
            90500000000000000000,
            2 days
        );
        uint256 amount0 = 0;
        uint256 amount1 = 0;

        (stakingDualRewards, , , amount0, amount1, ) = stakingDualRewardsFactory
            .stakingRewardsInfoByStakingToken(address(testToken1));

        bool success1 = rewardTokenA.transfer(
            address(stakingDualRewardsFactory),
            90500000000000000000
        );

        bool success2 = rewardTokenB.transfer(
            address(stakingDualRewardsFactory),
            90500000000000000000
        );

        stakingDualRewardsFactory.notifyRewardAmount(address(testToken1));
        assertEq(amount0, 90500000000000000000);
        assertEq(amount1, 90500000000000000000);

        uint256 rewardRateA = amount0 / (172800);
        uint256 rewardRateB = amount1 / (172800);

        assertEq(
            StakingDualRewards(stakingDualRewards).rewardRateA(),
            rewardRateA
        );
        assertEq(
            StakingDualRewards(stakingDualRewards).rewardRateB(),
            rewardRateB
        );

        uint256 _stakeAmount = 200e18;
        testToken1.transfer(bob, 10000e18);

        // Approve and stake
        hevm.prank(bob);
        testToken1.approve(stakingDualRewards, _stakeAmount);
        hevm.prank(bob);
        StakingDualRewards(stakingDualRewards).stake(_stakeAmount);

        assertEq(
            StakingDualRewards(stakingDualRewards).balanceOf(bob),
            _stakeAmount
        );

        uint256 _balance = StakingDualRewards(stakingDualRewards).balanceOf(
            bob
        );
        uint256 _rewardPerTokenA = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenA();

        uint256 _userRewardPerTokenAPaid = StakingDualRewards(
            stakingDualRewards
        ).userRewardPerTokenAPaid(bob);
        uint256 _rewardsA = StakingDualRewards(stakingDualRewards).rewardsA(
            bob
        );

        uint256 _rewardPerTokenAStored = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenAStored();
        uint256 _lastTimeRewardApplicable = StakingDualRewards(
            stakingDualRewards
        ).lastTimeRewardApplicable();

        uint256 _lastUpdateTime = StakingDualRewards(stakingDualRewards)
            .lastUpdateTime();

        uint256 _totalSupply = StakingDualRewards(stakingDualRewards)
            .totalSupply();

        console.log("Calculation for Earned");

        console.log(rewardRateA);

        console.log(_balance, _rewardPerTokenA);

        console.log(_userRewardPerTokenAPaid, _rewardsA);

        console.log("Calculation for rewardPerToken");

        console.log(_rewardPerTokenAStored, _lastTimeRewardApplicable);

        console.log(_lastUpdateTime, _totalSupply);
        // console.log(
        //     "Before 2 days",
        //     StakingDualRewards(stakingDualRewards).earnedA(bob)
        // );
        hevm.warp(3 days);
        console.log("+================================+");

        _balance = StakingDualRewards(stakingDualRewards).balanceOf(bob);
        _rewardPerTokenA = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenA();
        _userRewardPerTokenAPaid = StakingDualRewards(stakingDualRewards)
            .userRewardPerTokenAPaid(bob);
        _rewardsA = StakingDualRewards(stakingDualRewards).rewardsA(bob);
        _rewardPerTokenAStored = StakingDualRewards(stakingDualRewards)
            .rewardPerTokenAStored();
        _lastTimeRewardApplicable = StakingDualRewards(stakingDualRewards)
            .lastTimeRewardApplicable();

        _lastUpdateTime = StakingDualRewards(stakingDualRewards)
            .lastUpdateTime();

        _totalSupply = StakingDualRewards(stakingDualRewards).totalSupply();

        console.log("Calculation for Earned");
        console.log(
            "Earned:",
            StakingDualRewards(stakingDualRewards).earnedA(bob)
        );
        console.log(_balance, _rewardPerTokenA);

        console.log(_userRewardPerTokenAPaid, _rewardsA);

        console.log("Calculation for rewardPerToken");

        console.log(_rewardPerTokenAStored, _lastTimeRewardApplicable);

        console.log(_lastUpdateTime, _totalSupply);

        // console.log(
        //     "After 2 days",
        //     StakingDualRewards(stakingDualRewards).earnedA(bob)
        // );
    }
}
