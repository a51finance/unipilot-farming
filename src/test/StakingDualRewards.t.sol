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
    address public stakingDualRewardsContrat;
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

        (stakingDualRewardsContrat, , , , , ) = stakingDualRewardsFactory
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
        stakingToken.approve(stakingDualRewardsContrat, _stakeAmount);
        StakingDualRewards(stakingDualRewardsContrat).stake(_stakeAmount);
    }

    function setUp() public {
        stakingToken = new MockERC20("StakingToken", "ST");
        rewardTokenA = new MockERC20("RewardTokenA", "RTA");
        rewardTokenB = new MockERC20("RewardTokenB", "RTB");
        initialTime = (30 * 24 * 60 * 60);
        stakingDualRewardsFactory = new StakingDualRewardsFactory(initialTime);
        deployStakingContract(
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            100e18,
            150e18,
            initialTime
        );
    }
}
