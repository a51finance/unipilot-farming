// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./StakingDualRewards.sol";

import "./interfaces/IStakingDualRewardsFactory.sol";

contract StakingDualRewardsFactory is Ownable, IStakingDualRewardsFactory {
    // immutables
    uint256 public stakingRewardsGenesis;

    // the staking tokens for which the rewards contract has been deployed
    address[] public stakingTokens;

    // info about rewards for a particular staking token
    struct StakingRewardsInfo {
        address stakingRewards;
        address rewardsTokenA;
        address rewardsTokenB;
        uint256 rewardAmountA;
        uint256 rewardAmountB;
        uint256 duration;
    }

    // rewards info by staking token
    mapping(address => StakingRewardsInfo)
        public stakingRewardsInfoByStakingToken;

    constructor(uint256 _stakingRewardsGenesis) Ownable() {
        require(_stakingRewardsGenesis >= block.timestamp, "GTS");

        stakingRewardsGenesis = _stakingRewardsGenesis;
    }

    ///// permissioned functions

    // deploy a staking reward contract for the staking token, and store the reward amount
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    function deploy(
        address _owner,
        address stakingToken,
        address rewardsTokenA,
        address rewardsTokenB,
        uint256 rewardAmountA,
        uint256 rewardAmountB,
        uint256 rewardsDuration
    ) public onlyOwner {
        require(
            rewardsTokenA != address(0) && rewardsTokenB != address(0),
            "IRT(s)"
        );

        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[
            stakingToken
        ];

        require(info.stakingRewards == address(0), "AD");

        info.stakingRewards = address(
            new StakingDualRewards{
                salt: keccak256(
                    abi.encodePacked(
                        _owner,
                        address(this),
                        rewardsTokenA,
                        rewardsTokenB,
                        stakingToken
                    )
                )
            }(_owner, address(this), rewardsTokenA, rewardsTokenB, stakingToken)
        );

        info.rewardsTokenA = rewardsTokenA;
        info.rewardsTokenB = rewardsTokenB;

        info.rewardAmountA = rewardAmountA;
        info.rewardAmountB = rewardAmountB;
        info.duration = rewardsDuration;
        stakingTokens.push(stakingToken);

        emit Deployed(
            info.stakingRewards,
            stakingToken,
            rewardsTokenA,
            rewardsTokenB,
            rewardAmountA,
            rewardAmountB,
            rewardsDuration
        );
    }

    function update(
        address stakingToken,
        uint256 rewardAmountA,
        uint256 rewardAmountB,
        uint256 rewardsDuration
    ) public onlyOwner {
        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[
            stakingToken
        ];
        require(info.stakingRewards != address(0), "UND");

        info.rewardAmountA = rewardAmountA;
        info.rewardAmountB = rewardAmountB;
        info.duration = rewardsDuration;

        emit Updated(
            info.stakingRewards,
            rewardAmountA,
            rewardAmountB,
            rewardsDuration
        );
    }

    ///// permissionless functions

    // call notifyRewardAmount for all staking tokens.
    function notifyRewardAmounts() public {
        require(stakingTokens.length > 0, "CBD");
        for (uint256 i = 0; i < stakingTokens.length; i++) {
            notifyRewardAmount(stakingTokens[i]);
        }
    }

    // notify reward amount for an individual staking token.
    // this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
    function notifyRewardAmount(address stakingToken) public {
        require(block.timestamp >= stakingRewardsGenesis, "NNR");

        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[
            stakingToken
        ];
        require(info.stakingRewards != address(0), "NND");

        if (
            info.rewardAmountA > 0 &&
            info.rewardAmountB > 0 &&
            info.duration > 0
        ) {
            uint256 rewardAmountA = info.rewardAmountA;
            uint256 rewardAmountB = info.rewardAmountB;
            uint256 duration = info.duration;
            info.rewardAmountA = 0;
            info.rewardAmountB = 0;
            info.duration = 0;

            require(
                IERC20(info.rewardsTokenA).transfer(
                    info.stakingRewards,
                    rewardAmountA
                ),
                "TF"
            );
            require(
                IERC20(info.rewardsTokenB).transfer(
                    info.stakingRewards,
                    rewardAmountB
                ),
                "TF"
            );
            StakingDualRewards(info.stakingRewards).notifyRewardAmount(
                rewardAmountA,
                rewardAmountB,
                duration
            );
        }
    }

    function pullExtraTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }
}
