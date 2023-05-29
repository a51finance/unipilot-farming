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
    event RewardPaid(address indexed user, uint256 reward);

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
    // uint8 numberOfDays = 30;
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
        initialTime = (30 * 24 * 60 * 60);
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
        hevm.warp(block.timestamp + 2 days);

        // assertEq(
        //     StakingRewards(stakingContract).earned(address(this)) / 1e18,
        //     19
        // );

        // StakingRewards(stakingContract).getReward();

        // assertEq(
        //     StakingRewards(stakingContract).earned(address(this)) / 1e18,
        //     0
        // );
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

    // scenarios testing

    function testStakeWithoutNotifying() public {
        uint256 _stakeAmount = 10e18;
        uint256 _rewardAmount = 100e18;
        uint256 _duration = block.timestamp + 10 minutes;
        MockERC20 stakingTokenTest = new MockERC20("Token  Staking", "TS");

        // deploy staking vault

        stakingRewardsFactory.deploy(
            address(stakingTokenTest),
            address(rewardToken),
            _rewardAmount,
            _duration
        );

        (stakingContract, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingTokenTest));

        // approve tokens

        stakingTokenTest.approve(stakingContract, _stakeAmount);

        // stake

        StakingRewards(stakingContract).stake(_stakeAmount);

        // fast forward 10 mins

        hevm.warp(block.timestamp + 10 minutes);
        // console.log(
        //     "Before Notifying ====>",
        //     StakingRewards(stakingContract).earned(address(this))
        // );

        // Transfer tokens to factory and run notify

        bool success = rewardToken.transfer(
            address(stakingRewardsFactory),
            _rewardAmount
        );
        if (success) {
            stakingRewardsFactory.notifyRewardAmounts();
        } else {
            revert("Transfer Failed");
        }

        // fast forward 10 mins

        hevm.warp(block.timestamp + 10 minutes);

        // Check reward Again

        // console.log(
        //     "After Notifying ====>",
        //     StakingRewards(stakingContract).earned(address(this))
        // );
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

    // scenario

    function testScenario3() public {
        // step 1 deploy factory (did by setup function)
        // step 2 deploy Vault (did by setup function)
        // Step 3 Transfer Reward Tokens (did by setup function)

        // step 4 Run notifier

        StakingRewardsFactory(stakingRewardsFactory).notifyRewardAmount(
            address(stakingToken)
        );

        hevm.warp(block.timestamp + 31 days);
        StakingRewardsFactory(stakingRewardsFactory).update(
            address(stakingToken),
            200e18,
            5 days
        );

        stakeToken(50e18);
        hevm.warp(block.timestamp + 1 days);
    }

    function testScenario4() public {
        // Variable befor staking any values both
        //  are equal to zero and pass this test
        assertEq(StakingRewards(stakingContract).rewardPerTokenStored(), 0);
        assertEq(StakingRewards(stakingContract).rewardPerToken(), 0);

        // Stake some value
        stakeToken(10e18);

        // After 10 Minutes
        hevm.warp(block.timestamp + 10 minutes);

        // Store rewardPerToken in a variable
        uint256 previousRewardPerToken = StakingRewards(stakingContract)
            .rewardPerToken();

        // Stake another
        stakeToken(15e18);

        // previousRewardPerToken should be equal to
        // rewardPerTokenStored
        // console.log(
        //     previousRewardPerToken,
        //     StakingRewards(stakingContract).rewardPerTokenStored()
        // );

        // Pass the test
        assertEq(
            previousRewardPerToken,
            StakingRewards(stakingContract).rewardPerTokenStored()
        );
    }

    function testScenario5() public {
        MockERC20 stakingTokenTest = new MockERC20("STT", "STT");
        hevm.warp(block.timestamp + 10);
        stakingRewardsFactory.deploy(
            address(stakingTokenTest),
            address(rewardToken),
            86400e18,
            86400
        );

        bool success = rewardToken.transfer(
            address(stakingRewardsFactory),
            86400e18
        );
        if (success) {
            stakingRewardsFactory.notifyRewardAmounts();
        } else {
            revert("Transfer Failed");
        }

        (stakingContract, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingTokenTest));

        // console.log(StakingRewards(stakingContract).rewardRate() / 1e18);
        stakingTokenTest.approve(stakingContract, 100e18);
        StakingRewards(stakingContract).stake(100e18);
        stakingTokenTest.transfer(address(alice), 200e18);
        hevm.prank(alice);
        stakingTokenTest.approve(stakingContract, 200e18);
        hevm.prank(alice);
        StakingRewards(stakingContract).stake(200e18);

        hevm.warp(block.timestamp + 86400);

        // console.log(StakingRewards(stakingContract).earned(address(this)));

        // console.log(StakingRewards(stakingContract).earned(address(alice)));
    }

    function testNotifyScenario() public {
        MockERC20 stakingTokenTest = new MockERC20("Stake", "ST");
        StakingRewards stakingRewards;
        uint256 monthDuration = 86400 * 30;
        uint256 _15DaysDuration = 86400;

        hevm.warp(block.timestamp + 10);
        console.log(block.timestamp + monthDuration);
        rewardToken.transfer(address(stakingRewardsFactory), 10000e18);

        assertEq(
            rewardToken.balanceOf(address(stakingRewardsFactory)),
            10000e18
        );
        stakingRewardsFactory.deploy(
            address(stakingTokenTest),
            address(rewardToken),
            10000e18,
            monthDuration
        );

        stakingRewardsFactory.notifyRewardAmount(address(stakingTokenTest));
        (stakingContract, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingTokenTest));
        stakingRewards = StakingRewards(stakingContract);
        assertEq(
            stakingRewards.periodFinish(),
            block.timestamp + monthDuration
        );

        hevm.warp(block.timestamp + (86400 * 16));
        console.log(block.timestamp);
        stakingRewardsFactory.update(
            address(stakingTokenTest),
            10000e18,
            _15DaysDuration
        );
        rewardToken.transfer(address(stakingRewardsFactory), 10000e18);
        hevm.expectRevert(bytes("CRP"));
        stakingRewardsFactory.notifyRewardAmount(address(stakingTokenTest));
    }

    function testRewardTopupScenario() public {
        MockERC20 stakingTokenTest = new MockERC20("Stake", "ST");
        StakingRewards stakingRewards;
        uint256 monthDuration = 86400 * 30;
        uint256 periodFinish = 0;
        uint256 rewardRate = 0;
        uint256 lastUpdateTime = 0;
        uint256 totalSupply = 0;

        hevm.warp(block.timestamp + 10);
        rewardToken.transfer(address(stakingRewardsFactory), 10000e18);

        stakingRewardsFactory.deploy(
            address(stakingTokenTest),
            address(rewardToken),
            10000e18,
            monthDuration
        );

        stakingRewardsFactory.notifyRewardAmount(address(stakingTokenTest));
        (stakingContract, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingTokenTest));
        stakingRewards = StakingRewards(stakingContract);
        hevm.warp(block.timestamp + monthDuration + 10);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), 10000e18);

        stakingTokenTest.approve(address(stakingRewards), 100e18);
        stakingRewards.stake(100e18);

        totalSupply += 100e18;
        hevm.warp(block.timestamp + 100);

        rewardToken.transfer(address(stakingRewardsFactory), 10000e18);
        stakingRewardsFactory.update(
            address(stakingTokenTest),
            10000e18,
            monthDuration
        );
        periodFinish = block.timestamp + monthDuration;
        stakingRewardsFactory.notifyRewardAmount(address(stakingTokenTest));
        lastUpdateTime = block.timestamp;
        hevm.warp(block.timestamp + 1);

        // first staker will have 0 rewardPerTokenStored
        uint256 rewardPerTokenStored = 0;
        rewardRate = 10000e18 / monthDuration;
        uint256 lastTimeRewardApplicable = Math.min(
            block.timestamp,
            periodFinish
        );

        assertEq(stakingRewards.rewardPerTokenStored(), rewardPerTokenStored);

        uint256 rewardPerToken = rewardPerTokenStored +
            ((lastTimeRewardApplicable - lastUpdateTime) * rewardRate * 1e18) /
            totalSupply;

        assertEq(stakingRewards.rewardPerToken(), rewardPerToken);

        hevm.warp(block.timestamp + 10 days);

        stakingTokenTest.transfer(address(alice), 50e18);
        hevm.prank(address(alice));
        stakingTokenTest.approve(address(stakingRewards), 50e18);
        hevm.prank(address(alice));
        stakingRewards.stake(50e18);
        // totalSupply += 50e18;
        rewardPerToken =
            rewardPerTokenStored +
            ((lastTimeRewardApplicable =
                Math.min(block.timestamp, periodFinish) -
                lastUpdateTime) *
                rewardRate *
                1e18) /
            totalSupply;

        rewardPerTokenStored = rewardPerToken;

        lastUpdateTime = lastTimeRewardApplicable = Math.min(
            block.timestamp,
            periodFinish
        );

        hevm.warp(block.timestamp + 10 days);
        totalSupply += 50e18;
        lastTimeRewardApplicable = Math.min(block.timestamp, periodFinish);

        rewardPerToken =
            rewardPerTokenStored +
            (((lastTimeRewardApplicable - lastUpdateTime) * rewardRate * 1e18) /
                totalSupply);

        assertEq(stakingRewards.rewardPerToken(), rewardPerToken);
    }

    function testRewardAmount() public {
        MockERC20 stakingTokenTest = new MockERC20("Stake", "ST");
        StakingRewards stakingRewards;
        uint256 monthDuration = 86400 * 30;
        uint256 periodFinish = 0;
        uint256 rewardRate = 0;
        uint256 lastUpdateTime = 0;
        uint256 totalSupply = 0;

        hevm.warp(block.timestamp + 10);

        // Deploy Vault
        stakingRewardsFactory.deploy(
            address(stakingTokenTest),
            address(rewardToken),
            10000e18,
            monthDuration
        );

        // Transfer Amount
        rewardToken.transfer(address(stakingRewardsFactory), 10000e18);

        // Notify
        stakingRewardsFactory.notifyRewardAmount(address(stakingTokenTest));
        periodFinish = block.timestamp + monthDuration;

        (stakingContract, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingTokenTest));
        stakingRewards = StakingRewards(stakingContract);

        stakingTokenTest.transfer(address(alice), 100e18);

        // Stake after 1 Day
        hevm.warp(block.timestamp + 1 days);
        hevm.prank(address(alice));
        stakingTokenTest.approve(address(stakingRewards), 100e18);
        hevm.prank(address(alice));
        stakingRewards.stake(100e18);
        totalSupply += 100e18;
        lastUpdateTime = Math.min(block.timestamp, periodFinish);
        // roll forward to 15 days
        hevm.warp(block.timestamp + 15 days);

        // calculating the reward amount

        // first staker will have 0 rewardPerTokenStored because there was no
        // previous state of rewardPerToken

        uint256 rewardPerTokenStored = 0;
        rewardRate = 10000e18 / monthDuration;
        uint256 lastTimeRewardApplicable = Math.min(
            block.timestamp,
            periodFinish
        );

        uint256 rewardPerToken = rewardPerTokenStored +
            ((lastTimeRewardApplicable - lastUpdateTime) * rewardRate * 1e18) /
            totalSupply;

        console.log("rewardPerToken", rewardPerToken); // 49999999999999991040

        // earnedAmount
        uint256 userBalance = 100e18;

        // user didn't claimed rewardPreviously so
        // previous rewardPerTokenPaid will be 0
        uint256 rewardPerTokenPaid = 0;

        // similar for above reason the previousRewardPaid will also be 0
        uint256 previousRewardPaid = 0;

        uint256 earned = (userBalance * (rewardPerToken - rewardPerTokenPaid)) /
            1e18 +
            previousRewardPaid;

        console.log("earned", earned); //4999999999999999104000
        assertEq(stakingRewards.earned(address(alice)), earned);

        console.log("Balance Before", rewardToken.balanceOf(address(alice)));
        hevm.prank(address(alice));
        stakingRewards.getReward();
        console.log(
            "Balance After Subtracting Reward",
            rewardToken.balanceOf(address(alice))
        );
    }

    function testRewardGeneration() public {
        MockERC20 stakingTokenTest = new MockERC20("Stake", "ST");
        StakingRewards stakingRewards;
        uint256 monthDuration = 86400 * 30;
        uint256 periodFinish = 0;
        uint256 rewardRate = 0;
        uint256 lastUpdateTime = 0;
        uint256 totalSupply = 0;

        hevm.warp(block.timestamp + 10);

        // Deploy Vault
        stakingRewardsFactory.deploy(
            address(stakingTokenTest),
            address(rewardToken),
            10000e18,
            monthDuration
        );

        // Transfer Amount
        rewardToken.transfer(address(stakingRewardsFactory), 10000e18);

        // Notify
        stakingRewardsFactory.notifyRewardAmount(address(stakingTokenTest));
        rewardRate = 10000e18 / monthDuration;
        periodFinish = block.timestamp + monthDuration;

        (stakingContract, , , ) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingTokenTest));
        stakingRewards = StakingRewards(stakingContract);
        stakingTokenTest.transfer(address(alice), 300e18);

        // Stake after 1 Day
        hevm.warp(block.timestamp + 1 days);
        hevm.prank(address(alice));
        stakingTokenTest.approve(address(stakingRewards), 100e18);
        hevm.prank(address(alice));
        stakingRewards.stake(100e18);
        totalSupply += 100e18;
        lastUpdateTime = Math.min(block.timestamp, periodFinish);

        hevm.warp(block.timestamp + 10 days);
        uint256 lastTimeRewardApplicable = Math.min(
            block.timestamp,
            periodFinish
        );
        uint256 rewardPerTokenStored = 0;
        uint256 rewardPerToken = rewardPerTokenStored +
            ((lastTimeRewardApplicable - lastUpdateTime) * rewardRate * 1e18) /
            totalSupply;

        assertEq(stakingRewards.rewardPerToken(), rewardPerToken);

        hevm.warp(block.timestamp + 10 days);

        // Stake
        hevm.prank(address(alice));
        stakingTokenTest.approve(address(stakingRewards), 100e18);

        rewardPerToken =
            rewardPerTokenStored +
            ((Math.min(block.timestamp, periodFinish) - lastUpdateTime) *
                rewardRate *
                1e18) /
            totalSupply;
        lastUpdateTime = Math.min(block.timestamp, periodFinish);
        rewardPerTokenStored = rewardPerToken;
        uint256 previousRewardEarned = earned(100e18, rewardPerToken, 0, 0);
        uint256 userRewardPerTokenPaid = rewardPerTokenStored;

        assertEq(stakingRewards.earned(address(alice)), previousRewardEarned);

        hevm.prank(address(alice));
        stakingRewards.stake(100e18);
        totalSupply += 100e18;

        assertEq(
            stakingRewards.userRewardPerTokenPaid(address(alice)),
            userRewardPerTokenPaid
        );

        hevm.warp(block.timestamp + 10 days);

        rewardPerToken =
            rewardPerTokenStored +
            ((Math.min(block.timestamp, periodFinish) - lastUpdateTime) *
                rewardRate *
                1e18) /
            totalSupply;

        assertEq(
            stakingRewards.earned(address(alice)),
            earned(
                200e18,
                rewardPerToken,
                userRewardPerTokenPaid,
                previousRewardEarned
            )
        );
    }

    function earned(
        uint256 b,
        uint256 rpt,
        uint256 rptp,
        uint256 prp
    ) internal pure returns (uint256 earnedAmount) {
        earnedAmount = (b * (rpt - rptp)) / 1e18 + prp;
    }
}
