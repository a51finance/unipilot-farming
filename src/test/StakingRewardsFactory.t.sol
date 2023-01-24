// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "../StakingRewardsFactory.sol";
import "../StakingRewards.sol";
import "forge-std/console.sol";

contract StakingRewardsFactoryTest is Test {
    event Deployed(
        address indexed stakingRewardContract,
        address stakingToken,
        address rewardToken,
        uint256 rewardAmount,
        uint256 rewardsDuration
    );

    event Updated(
        address indexed stakingRewardContract,
        uint256 rewardAmount,
        uint256 rewardsDuration
    );

    event RewardAdded(uint256 reward, uint256 periodFinish);

    struct TestStakingRewardsInfo {
        address _stakingRewards;
        address _rewardToken;
        uint256 _rewardAmount;
        uint256 _duration;
    }
    Vm hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    StakingRewardsFactory public stakingRewardsFactory;
    StakingRewards public stakingRewards;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
    uint256 stakeAmount = 10e18;

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
    }

    function setUp() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        rewardToken = new MockERC20("Token Test Reward", "TTR");
        stakingRewardsFactory = new StakingRewardsFactory(block.timestamp + 1);
    }

    // Deploy function

    function testDeployStakingRewardsContract() public {
        hevm.warp(block.timestamp + 10);

        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );

        bool success = rewardToken.transfer(
            address(stakingRewardsFactory),
            100e18
        );
        if (success) {
            stakingRewardsFactory.notifyRewardAmounts();
        } else {
            revert("Transfer Failed");
        }
    }

    function testStakingRewardsInfo() public {
        hevm.warp(block.timestamp + 10);
        uint256 rewardAmount = 100e18;

        uint256 rewardsDuration = block.timestamp + 2 days;
        hevm.recordLogs();

        stakingRewardsFactory.deploy(
            address(stakingToken),
            address(rewardToken),
            rewardAmount,
            rewardsDuration
        );

        Vm.Log[] memory entries = hevm.getRecordedLogs();

        (
            address stakingRewardsContract,
            address _rewardToken,
            uint256 _rewardAmount,
            uint256 _duration
        ) = stakingRewardsFactory.stakingRewardsInfoByStakingToken(
                address(stakingToken)
            );

        address stakingReward = address(uint160(uint256(entries[0].topics[1])));

        assertEq(stakingReward, stakingRewardsContract);
        assertEq(address(rewardToken), address(_rewardToken));
        assertEq(address(rewardAmount), address(_rewardAmount));
        assertEq(rewardsDuration, _duration);
    }

    function testCannotDeployWithZeroAddress() public {
        hevm.warp(block.timestamp + 10);

        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );

        hevm.expectRevert(bytes("AD"));
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );
    }

    function testCannotDeployWithInvalidAddress() public {
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );
        hevm.warp(block.timestamp + 10);
        hevm.expectRevert(bytes("IA"));
        deployStakingContract(
            address(0),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );

        hevm.warp(block.timestamp + 10);
        hevm.expectRevert(bytes("IA"));
        deployStakingContract(
            address(stakingToken),
            address(0),
            100e18,
            block.timestamp + 2 days
        );

        hevm.expectRevert(bytes("IA"));
        deployStakingContract(
            address(0),
            address(0),
            100e18,
            block.timestamp + 2 days
        );
    }

    function testCannotDeployWithSameAddresses() public {
        hevm.warp(block.timestamp + 10);
        hevm.expectRevert(bytes("IA"));
        stakingRewardsFactory.deploy(
            address(stakingToken),
            address(stakingToken),
            100e18,
            block.timestamp + 2 days
        );
    }

    function testCannotDeployWithZeroAmount() public {
        hevm.warp(block.timestamp + 10);
        hevm.expectRevert(bytes("ZR"));
        stakingRewardsFactory.deploy(
            address(stakingToken),
            address(rewardToken),
            0,
            block.timestamp + 2 days
        );
    }

    // Update function

    function testUpdateStakingContract() public {
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );
        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        stakingRewardsFactory.update(
            address(stakingToken),
            200e18,
            futureDuration
        );
        (, , uint256 rewardAmount, uint256 duration) = stakingRewardsFactory
            .stakingRewardsInfoByStakingToken(address(stakingToken));

        assertEq(duration, futureDuration);
        assertEq(rewardAmount, 200e18);
    }

    function testCannotUpdateStakingContract() public {
        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        hevm.expectRevert(bytes("UND"));
        stakingRewardsFactory.update(
            address(stakingToken),
            100e18,
            futureDuration
        );
    }

    function testCannotUpdateStakingContractWithOwner() public {
        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        hevm.expectRevert(bytes("Ownable: caller is not the owner"));
        hevm.prank(alice);
        stakingRewardsFactory.update(
            address(stakingToken),
            100e18,
            futureDuration
        );
    }

    // NotifyRewardAmounts function

    function testNotifyRewardAmount() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            10e18,
            block.timestamp + 2 days
        );
        stakingRewardsFactory.notifyRewardAmount(address(stakingToken));
    }

    function testNotifyRewardAmounts() public {
        for (uint256 i = 0; i < 5; i++) {
            stakingToken = new MockERC20("Token Test Staking", "TTS");
            deployStakingContract(
                address(stakingToken),
                address(rewardToken),
                10e18,
                block.timestamp + 2 days
            );
        }
        stakingRewardsFactory.notifyRewardAmounts();
    }

    function testCannotNotifyRewardAmounts() public {
        hevm.expectRevert(bytes("CBD"));
        stakingRewardsFactory.notifyRewardAmounts();
    }

    // notifyRewardAmount function
    function testCannotTestNotifyRewardAmount() public {
        stakingRewardsFactory.deploy(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );
        rewardToken.transfer(address(stakingRewardsFactory), 100e18);
        hevm.expectRevert(bytes("NNR"));
        stakingRewardsFactory.notifyRewardAmounts();
    }

    function testCannotTestNotifyRewardAmountWithZeroAddress() public {
        hevm.warp(block.timestamp + 10);
        stakingRewardsFactory.deploy(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );
        rewardToken.transfer(address(stakingRewardsFactory), 100e18);
        hevm.expectRevert(bytes("NND"));
        stakingRewardsFactory.notifyRewardAmount(address(0));
    }

    // pullExtraTokens
    function testPullErc20RewardToken() public {
        hevm.warp(block.timestamp + 10);

        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );

        uint256 _balanceBefore = rewardToken.balanceOf(address(this));

        rewardToken.transfer(address(stakingRewardsFactory), 2948e18);

        stakingRewardsFactory.notifyRewardAmount(address(stakingToken));

        stakingRewardsFactory.pullExtraTokens(
            address(rewardToken),
            2948e18 - 100e18
        );
        uint256 _balanceAfer = rewardToken.balanceOf(address(this));

        assertEq(_balanceAfer, _balanceBefore - 100e18);
    }

    function testPullErc20RandomToken() public {
        MockERC20 randomToken = new MockERC20("Random Token", "RT");

        hevm.warp(block.timestamp + 10);

        deployStakingContract(
            address(stakingToken),
            address(rewardToken),
            100e18,
            block.timestamp + 2 days
        );

        uint256 _balanceBefore = randomToken.balanceOf(address(this));

        rewardToken.transfer(address(stakingRewardsFactory), 100e18);
        randomToken.transfer(address(stakingRewardsFactory), 4857e18);

        stakingRewardsFactory.notifyRewardAmount(address(stakingToken));

        stakingRewardsFactory.pullExtraTokens(address(randomToken), 4857e18);

        uint256 _balanceAfer = randomToken.balanceOf(address(this));

        assertEq(_balanceAfer, _balanceBefore);
    }
}
