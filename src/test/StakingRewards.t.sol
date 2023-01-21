// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockERC20Permit.sol";
import "../StakingRewardsFactory.sol";
import "../StakingRewards.sol";
import "forge-std/console.sol";

contract StakingRewardsTest is Test {
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    Vm hevm = Vm(HEVM_ADDRESS);
    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    StakingRewardsFactory public stakingRewardsFactory;
    // StakingRewards public stakingRewards;
    address public stakingContract;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
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

    function testEarnedValueWithMultipleUsers() public {
        stakingToken.transfer(alice, 10000e18);
        stakingToken.transfer(bob, 10000e18);
        uint256 aliceEarned;
        uint256 bobEarned;

        stakeToken(15e18);

        uint256 user1Earned = 15e18 *
            ((StakingRewards(stakingContract).rewardPerToken() - 0) / 1e18) +
            0;
        assertEq(
            user1Earned,
            StakingRewards(stakingContract).earned(address(this))
        );

        // alice

        hevm.startPrank(alice);

        stakeToken(10e18);
        hevm.warp(block.timestamp + 1 minutes);

        aliceEarned =
            (10e18 * (StakingRewards(stakingContract).rewardPerToken() - 0)) /
            1e18;

        assertEq(
            aliceEarned,
            StakingRewards(stakingContract).earned(address(alice))
        );
        uint256 previousReward = aliceEarned;

        StakingRewards(stakingContract).getReward();
        assertEq(rewardToken.balanceOf(alice), aliceEarned);
        previousReward = 0;

        uint256 previousRewardPerToken = StakingRewards(stakingContract)
            .rewardPerToken();

        assertEq(
            previousRewardPerToken,
            StakingRewards(stakingContract).userRewardPerTokenPaid(alice)
        );

        uint256 balance = StakingRewards(stakingContract).balanceOf(alice);

        uint256 previouslyEarned = (balance *
            (StakingRewards(stakingContract).rewardPerToken() -
                previousRewardPerToken)) / 1e18;

        stakeToken(25e18);

        hevm.warp(block.timestamp + 2 minutes);

        previouslyEarned = StakingRewards(stakingContract).earned(alice);
        previousRewardPerToken = StakingRewards(stakingContract)
            .rewardPerToken();

        previousReward = previouslyEarned;

        stakeToken(45e18);

        hevm.warp(block.timestamp + 5 minutes);
        balance = StakingRewards(stakingContract).balanceOf(alice);

        aliceEarned =
            ((balance *
                (StakingRewards(stakingContract).rewardPerToken() -
                    previousRewardPerToken)) / 1e18) +
            previousReward;

        assertEq(
            aliceEarned,
            StakingRewards(stakingContract).earned(address(alice))
        );

        hevm.stopPrank();

        // bob

        hevm.startPrank(bob);
        previousRewardPerToken = StakingRewards(stakingContract)
            .rewardPerToken();
        previousReward = 0;

        stakeToken(300e18);
        balance = StakingRewards(stakingContract).balanceOf(bob);
        bobEarned =
            balance *
            ((StakingRewards(stakingContract).rewardPerToken() - 0) / 1e18) +
            0;
        assertEq(
            bobEarned,
            StakingRewards(stakingContract).earned(address(bob))
        );

        hevm.stopPrank();

        hevm.warp(block.timestamp + 1 minutes);
    }

    function testExitFunction() public {
        stakingToken.transfer(user2, 200e18);

        hevm.startPrank(user2);

        stakeToken(200e18);
        hevm.warp(block.timestamp + 10 minutes);
        uint256 reward = StakingRewards(stakingContract).earned(address(user2));
        StakingRewards(stakingContract).exit();
        uint256 finalOutPut = stakingToken.balanceOf(address(user2)) +
            rewardToken.balanceOf(address(user2));
        uint256 expectedOutPut = reward + 200e18;
        assertEq(finalOutPut, expectedOutPut);
        assertEq(StakingRewards(stakingContract).balanceOf(address(user2)), 0);

        hevm.stopPrank();
    }

    // Notify Reward Amount
    function testCannotPassRequireChecksNotifyRewardAmount() public {
        stakingRewardsFactory = new StakingRewardsFactory(block.timestamp + 1);
        uint256 iTime = block.timestamp + 10 days;
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            iTime
        );

        // reducing existing period

        hevm.expectRevert(bytes("CRP"));
        hevm.prank(address(stakingRewardsFactory));
        StakingRewards(stakingContract).notifyRewardAmount(
            20e18,
            block.timestamp + 2 days
        );
        uint256 _periodFinish = 0;
        uint256 _rewardRate = 0;
        if (block.timestamp >= _periodFinish) {
            _rewardRate = 100e18 / iTime;
            assertEq(_rewardRate, StakingRewards(stakingContract).rewardRate());
        }

        // Providing too high reward

        hevm.warp(block.timestamp + 7 days);
        uint256 newDuration = block.timestamp + 5 days;
        hevm.expectRevert(bytes("RTH"));
        hevm.prank(address(stakingRewardsFactory));
        StakingRewards(stakingContract).notifyRewardAmount(
            2000000e18,
            newDuration
        );
    }

    function testStakeWithPermit() public {
        hevm.chainId(5);

        stakingRewardsFactory = new StakingRewardsFactory(block.timestamp + 1);
        tokenPermit = new MockERC20Permit("Token", "TKN", 18, 5);

        deployStakingContract(
            address(tokenPermit),
            address(rewardToken),
            100e18,
            block.timestamp + 10 days
        );

        (address stakingRewards, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(tokenPermit));

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);
        tokenPermit.mint(owner, 1000000e18);
        hevm.prank(owner);
        uint256 nonce = hevm.getNonce(address(100));

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    tokenPermit.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(stakingRewards),
                            10e18,
                            nonce,
                            block.timestamp
                        )
                    )
                )
            )
        );
        hevm.prank(owner);
        StakingRewards(stakingRewards).stakeWithPermit(
            10e18,
            block.timestamp,
            v,
            r,
            s
        );
    }

    function testCannotStakePermitWithZero() public {
        hevm.chainId(5);

        stakingRewardsFactory = new StakingRewardsFactory(block.timestamp + 1);
        tokenPermit = new MockERC20Permit("Token", "TKN", 18, 5);

        deployStakingContract(
            address(tokenPermit),
            address(rewardToken),
            100e18,
            block.timestamp + 10 days
        );

        (address stakingRewards, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(tokenPermit));

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);
        tokenPermit.mint(owner, 1000000e18);
        hevm.prank(owner);
        uint256 nonce = hevm.getNonce(address(100));

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    tokenPermit.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(stakingRewards),
                            0,
                            nonce,
                            block.timestamp
                        )
                    )
                )
            )
        );

        hevm.expectRevert(bytes("CSZ"));
        hevm.prank(owner);
        StakingRewards(stakingRewards).stakeWithPermit(
            0,
            block.timestamp,
            v,
            r,
            s
        );
    }
}
