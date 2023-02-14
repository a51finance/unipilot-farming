// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

abstract contract DualRewardsDistributionRecipient {
    address public dualRewardsDistribution;

    function notifyRewardAmount(
        uint256 rewardA,
        uint256 rewardB,
        uint256 rewardsDuration
    ) external virtual;

    modifier onlyDualRewardsDistribution() {
        require(
            msg.sender == dualRewardsDistribution,
            "Caller is not DualRewardsDistribution contract"
        );
        _;
    }
}
