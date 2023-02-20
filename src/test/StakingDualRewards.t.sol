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
            address(this),
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
            address(this),
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
}
