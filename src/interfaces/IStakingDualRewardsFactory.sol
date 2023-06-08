// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

interface IStakingDualRewardsFactory {
    event Deployed(
        address indexed stakingRewardContract,
        address stakingToken,
        address rewardTokenA,
        address rewardTokenB,
        uint256 rewardAmountA,
        uint256 rewardAmountB,
        uint256 rewardsDuration
    );

    event Updated(
        address indexed stakingRewardContract,
        uint256 rewardAmountA,
        uint256 rewardAmountB,
        uint256 rewardsDuration
    );
}
