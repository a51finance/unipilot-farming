// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "../StakingDualRewardsFactory.sol";
import "../StakingDualRewards.sol";
import "forge-std/console.sol";

contract StakingRewardsFactoryTest is Test {
    Vm hevm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    StakingDualRewardsFactory public stakingDualRewardsFactory;
    StakingDualRewards public stakingDualRewards;
    address public stakingDualRewardsContrat;
    MockERC20 public stakingToken;
    MockERC20 public rewardTokenA;
    MockERC20 public rewardTokenB;

    address alice = hevm.addr(1);
    address bob = hevm.addr(2);
    address user1 = hevm.addr(3);
    address user2 = hevm.addr(4);

    event Deployed(
        address indexed stakingRewardContract,
        address stakingToken,
        address rewardTokenA,
        address rewardTokenB,
        uint256 rewardAmountA,
        uint256 rewardAmountB,
        uint256 rewardsDuration
    );

    function setUp() public {
        stakingToken = new MockERC20("StakingToken", "ST");
        rewardTokenA = new MockERC20("RewardTokenA", "RTA");
        rewardTokenB = new MockERC20("RewardTokenB", "RTB");
        stakingDualRewardsFactory = new StakingDualRewardsFactory(
            block.timestamp + 1
        );
    }

    function deployStakingContract(
        address _stakingToken,
        address _rewardTokenA,
        address _rewardTokenB,
        uint256 _rewardAmountA,
        uint256 _rewardAmountB,
        uint256 _duration
    ) internal {
        hevm.warp(block.timestamp + 1 minutes);

        // uint256 rewardAmountA = 200e18;
        // uint256 rewardAmountB = 100e18;
        // uint256 rewardsDuration = 30 days;

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

    // Deploy Function Tests
    function testDeployStakingRewardsContract() public {
        hevm.warp(block.timestamp + 10);
        hevm.recordLogs();

        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );

        Vm.Log[] memory entries = hevm.getRecordedLogs();

        (
            address stakingDualRewardsContract,
            ,
            ,
            ,
            ,

        ) = stakingDualRewardsFactory.stakingRewardsInfoByStakingToken(
                address(stakingToken)
            );

        address stakingReward = address(uint160(uint256(entries[1].topics[1])));

        assertEq(stakingReward, stakingDualRewardsContract);
    }

    function testStakingRewardsInfo() public {
        hevm.warp(block.timestamp + 10);
        hevm.recordLogs();
        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );

        address _stakingDualRewardsContract;
        address _rewardTokenA;
        address _rewardTokenB;
        uint256 _rewardAmountA;
        uint256 _rewardAmountB;
        uint256 _duration;

        (
            _stakingDualRewardsContract,
            _rewardTokenA,
            _rewardTokenB,
            _rewardAmountA,
            _rewardAmountB,
            _duration
        ) = stakingDualRewardsFactory.stakingRewardsInfoByStakingToken(
            address(stakingToken)
        );

        Vm.Log[] memory entries = hevm.getRecordedLogs();
        assertEq(
            address(uint160(uint256(entries[1].topics[1]))),
            _stakingDualRewardsContract
        );
        assertEq(_rewardTokenA, address(rewardTokenA));
        assertEq(_rewardTokenB, address(rewardTokenB));
        assertEq(_rewardAmountA, 200e18);
        assertEq(_rewardAmountB, 100e18);
        assertEq(_duration, 2 days);
    }

    function testCannotDifferentAddressWithDeployment() public {
        hevm.warp(block.timestamp + 1 minutes);

        hevm.expectRevert(bytes("SRT"));
        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenA),
            200e18,
            100e18,
            2 days
        );

        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );
        hevm.expectRevert(bytes("AD"));
        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );

        hevm.expectRevert(bytes("IRT(s)"));
        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(0),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );

        hevm.expectRevert(bytes("IRT(s)"));
        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(0),
            0,
            0,
            2 days
        );

        hevm.expectRevert(bytes("ZR"));
        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            0,
            0,
            2 days
        );
    }

    function tesEmitDeployEvent() public {
        hevm.recordLogs();
        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );

        Vm.Log[] memory entries = hevm.getRecordedLogs();

        assertEq(
            abi.encode(
                address(stakingToken),
                address(rewardTokenA),
                address(rewardTokenB),
                200e18,
                100e18,
                2 days
            ),
            entries[1].data
        );
    }

    // update functions

    function testUpdateStakingContract() public {
        deployStakingContract(
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );
        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        uint256 futureRewardAmountA = 250e18;
        uint256 futureRewardAmountB = 200e18;
        stakingDualRewardsFactory.update(
            address(stakingToken),
            futureRewardAmountA,
            futureRewardAmountB,
            futureDuration
        );

        (
            ,
            ,
            ,
            uint256 _rewardAmountA,
            uint256 _rewardAmountB,
            uint256 _duration
        ) = stakingDualRewardsFactory.stakingRewardsInfoByStakingToken(
                address(stakingToken)
            );

        assertEq(_duration, futureDuration);
        assertEq(_rewardAmountA, futureRewardAmountA);
        assertEq(_rewardAmountB, futureRewardAmountB);
    }

    function testUpdateStakingContractWithLessReward() public {
        deployStakingContract(
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );
        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        uint256 futureRewardAmountA = 100e18;
        uint256 futureRewardAmountB = 50e18;
        stakingDualRewardsFactory.update(
            address(stakingToken),
            futureRewardAmountA,
            futureRewardAmountB,
            futureDuration
        );

        (
            ,
            ,
            ,
            uint256 _rewardAmountA,
            uint256 _rewardAmountB,
            uint256 _duration
        ) = stakingDualRewardsFactory.stakingRewardsInfoByStakingToken(
                address(stakingToken)
            );

        assertEq(_duration, futureDuration);
        assertEq(_rewardAmountA, futureRewardAmountA);
        assertEq(_rewardAmountB, futureRewardAmountB);
    }

    function testCannotUpdateStakingContract() public {
        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        uint256 futureRewardAmountA = 250e18;
        uint256 futureRewardAmountB = 200e18;
        hevm.expectRevert(bytes("UND"));
        stakingDualRewardsFactory.update(
            address(stakingToken),
            futureRewardAmountA,
            futureRewardAmountB,
            futureDuration
        );
    }

    function testCannotUpdateStakingContractWithOwner() public {
        hevm.warp(block.timestamp + 1 days);
        uint256 futureDuration = block.timestamp + 5 days;
        hevm.expectRevert(bytes("Ownable: caller is not the owner"));
        hevm.prank(alice);
        stakingDualRewardsFactory.update(
            address(stakingToken),
            100e18,
            200e18,
            futureDuration
        );
    }

    function testEmitUpdate() public {
        deployStakingContract(
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            200e18,
            100e18,
            2 days
        );

        hevm.warp(block.timestamp + 1 days);

        uint256 futureDuration = block.timestamp + 5 days;
        hevm.recordLogs();

        stakingDualRewardsFactory.update(
            address(stakingToken),
            200e18,
            100e18,
            futureDuration
        );

        Vm.Log[] memory entries = hevm.getRecordedLogs();

        assertEq(abi.encode(200e18, 100e18, futureDuration), entries[0].data);
    }

    // NotifyRewardAmounts function
    function testNotifyRewardAmount() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        deployStakingContract(
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            10e18,
            20e18,
            block.timestamp + 2 days
        );
        assertEq(
            rewardTokenA.balanceOf(address(stakingDualRewardsContrat)),
            10e18
        );
        assertEq(
            rewardTokenB.balanceOf(address(stakingDualRewardsContrat)),
            20e18
        );

        stakingDualRewardsFactory.notifyRewardAmount(address(stakingToken));
        assertEq(rewardTokenA.balanceOf(address(stakingDualRewardsFactory)), 0);
        assertEq(rewardTokenB.balanceOf(address(stakingDualRewardsFactory)), 0);
    }

    mapping(uint256 => address) stakingContractInfo;

    function testNotifyRewardAmounts() public {
        for (uint256 i = 0; i < 5; i++) {
            stakingToken = new MockERC20("Token Test Staking", "TTS");
            stakingDualRewardsFactory.deploy(
                address(this),
                address(stakingToken),
                address(rewardTokenA),
                address(rewardTokenB),
                20e18,
                10e18,
                2 days
            );

            (stakingDualRewardsContrat, , , , , ) = stakingDualRewardsFactory
                .stakingRewardsInfoByStakingToken(address(stakingToken));

            stakingContractInfo[i] = stakingDualRewardsContrat;

            rewardTokenA.transfer(address(stakingDualRewardsFactory), 20e18);
            rewardTokenB.transfer(address(stakingDualRewardsFactory), 10e18);
        }
        assertEq(
            rewardTokenA.balanceOf(address(stakingDualRewardsFactory)),
            20e18 * 5
        );
        assertEq(
            rewardTokenB.balanceOf(address(stakingDualRewardsFactory)),
            10e18 * 5
        );
        hevm.warp(block.timestamp + 1 minutes);
        stakingDualRewardsFactory.notifyRewardAmounts();
        console.log(stakingContractInfo[0]);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(rewardTokenA.balanceOf(stakingContractInfo[i]), 20e18);
            assertEq(rewardTokenB.balanceOf(stakingContractInfo[i]), 10e18);
        }
    }

    function testCannotNotifyRewardWithoutAmounts() public {
        stakingToken = new MockERC20("Token Test Staking", "TTS");
        stakingDualRewardsFactory.deploy(
            address(this),
            address(stakingToken),
            address(rewardTokenA),
            address(rewardTokenB),
            20e18,
            10e18,
            2 days
        );

        hevm.warp(block.timestamp + 1 minutes);
        hevm.expectRevert(bytes(""));
        stakingDualRewardsFactory.notifyRewardAmount(address(stakingToken));
    }
}
