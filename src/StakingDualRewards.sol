// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./interfaces/IStakingDualRewards.sol";
import "./interfaces/SafeERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Math.sol";
import "./base/DualRewardsDistributionRecipient.sol";
import "./base/Pausable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract StakingDualRewards is
    IStakingDualRewards,
    DualRewardsDistributionRecipient,
    ReentrancyGuard,
    Pausable
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsTokenA;
    IERC20 public rewardsTokenB;
    IERC20 public stakingToken;
    uint256 public periodFinish = 0;
    uint256 public rewardRateA = 0;
    uint256 public rewardRateB = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenAStored;
    uint256 public rewardPerTokenBStored;

    mapping(address => uint256) public userRewardPerTokenAPaid;
    mapping(address => uint256) public userRewardPerTokenBPaid;
    mapping(address => uint256) public rewardsA;
    mapping(address => uint256) public rewardsB;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _owner,
        address _dualRewardsDistribution,
        address _rewardsTokenA,
        address _rewardsTokenB,
        address _stakingToken
    ) Ownable() {
        transferOwnership(_owner);
        require(_rewardsTokenA != _rewardsTokenB, "SRT");
        rewardsTokenA = IERC20(_rewardsTokenA);
        rewardsTokenB = IERC20(_rewardsTokenB);
        stakingToken = IERC20(_stakingToken);
        dualRewardsDistribution = _dualRewardsDistribution;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view override returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerTokenA() public view override returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenAStored;
        }
        return
            rewardPerTokenAStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRateA)
                    .mul(1e18)
                    .div(_totalSupply)
            );
    }

    function rewardPerTokenB() public view override returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenBStored;
        }

        return
            rewardPerTokenBStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRateB)
                    .mul(1e18)
                    .div(_totalSupply)
            );
    }

    function earnedA(address account) public view override returns (uint256) {
        return
            _balances[account]
                .mul(rewardPerTokenA().sub(userRewardPerTokenAPaid[account]))
                .div(1e18)
                .add(rewardsA[account]);
    }

    function earnedB(address account) public view override returns (uint256) {
        return
            _balances[account]
                .mul(rewardPerTokenB().sub(userRewardPerTokenBPaid[account]))
                .div(1e18)
                .add(rewardsB[account]);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount)
        external
        override
        nonReentrant
        notPaused
        updateReward(msg.sender)
    {
        require(amount > 0, "CSZ");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        override
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "CWZ");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public override nonReentrant updateReward(msg.sender) {
        uint256 rewardAmountA = rewardsA[msg.sender];
        if (rewardAmountA > 0) {
            rewardsA[msg.sender] = 0;
            rewardsTokenA.safeTransfer(msg.sender, rewardAmountA);
            emit RewardPaid(msg.sender, address(rewardsTokenA), rewardAmountA);
        }

        uint256 rewardAmountB = rewardsB[msg.sender];
        if (rewardAmountB > 0) {
            rewardsB[msg.sender] = 0;
            rewardsTokenB.safeTransfer(msg.sender, rewardAmountB);
            emit RewardPaid(msg.sender, address(rewardsTokenB), rewardAmountB);
        }
    }

    function exit() external override {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(
        uint256 rewardA,
        uint256 rewardB,
        uint256 rewardsDuration
    ) external override onlyDualRewardsDistribution updateReward(address(0)) {
        require(block.timestamp.add(rewardsDuration) >= periodFinish, "CRP");

        if (block.timestamp >= periodFinish) {
            rewardRateA = rewardA.div(rewardsDuration);
            rewardRateB = rewardB.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);

            uint256 leftoverA = remaining.mul(rewardRateA);
            rewardRateA = rewardA.add(leftoverA).div(rewardsDuration);

            uint256 leftoverB = remaining.mul(rewardRateB);
            rewardRateB = rewardB.add(leftoverB).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balanceA = rewardsTokenA.balanceOf(address(this));
        require(rewardRateA <= balanceA.div(rewardsDuration), "RATH");

        uint256 balanceB = rewardsTokenB.balanceOf(address(this));
        require(rewardRateB <= balanceB.div(rewardsDuration), "RBTH");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(rewardA, rewardB, periodFinish);
    }

    // Added to support recovering LP Rewards in case of emergency
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
    {
        require(tokenAddress != address(stakingToken), "CWT");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenAStored = rewardPerTokenA();
        rewardPerTokenBStored = rewardPerTokenB();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewardsA[account] = earnedA(account);
            userRewardPerTokenAPaid[account] = rewardPerTokenAStored;
        }

        if (account != address(0)) {
            rewardsB[account] = earnedB(account);
            userRewardPerTokenBPaid[account] = rewardPerTokenBStored;
        }
        _;
    }
}
