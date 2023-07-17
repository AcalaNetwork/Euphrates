// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/Staking.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract SimpleStaking is Staking {
    constructor() {}
}

contract SimpleStakingTest is Test {
    SimpleStaking public staking;
    IERC20 public shareTokenA;
    IERC20 public shareTokenB;
    IERC20 public RewardTokenA;
    IERC20 public RewardTokenB;
    IERC20 public RewardTokenC;
    IERC20 public RewardTokenD;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);
    address public CHARLIE = address(0x3333);
    address public DAVE = address(0x4444);

    event NewPool(uint256 poolId, IERC20 shareType);
    event RewardsDeductionRateSet(uint256 poolId, uint256 rate);
    event RewardRuleUpdated(uint256 poolId, IERC20 rewardType, uint256 rewardRate, uint256 endTime);

    function setUp() public {
        staking = new SimpleStaking();
        shareTokenA = new ERC20PresetFixedSupply("ShareTokenA", "STA", 10_000_000, BOB);
        shareTokenB = new ERC20PresetFixedSupply("ShareTokenB", "STB", 10_000_000, BOB);
        RewardTokenA = new ERC20PresetFixedSupply("RewardTokenA", "RTA", 10_000_000, ALICE);
        RewardTokenB = new ERC20PresetFixedSupply("RewardTokenB", "RTB", 10_000_000, ALICE);
        RewardTokenC = new ERC20PresetFixedSupply("RewardTokenC", "RTC", 10_000_000, ALICE);
        RewardTokenD = new ERC20PresetFixedSupply("RewardTokenD", "RTD", 10_000_000, ALICE);
    }

    function test_addPool_RevertZeroShareType() public {
        vm.expectRevert("share token is zero address");
        staking.addPool(IERC20(address(0)));
    }

    function test_addPool_Success() public {
        assertEq(staking.poolIndex(), 0);
        assertEq(address(staking.shareTypes(0)), address(0));
        assertEq(staking.totalShares(0), 0);

        vm.expectEmit(false, false, false, true);
        emit NewPool(0, shareTokenA);
        staking.addPool(shareTokenA);
        assertEq(staking.poolIndex(), 1);
        assertEq(address(staking.shareTypes(0)), address(shareTokenA));
        assertEq(staking.totalShares(0), 0);
    }

    function test_setRewardsDeductionRate_RevertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.setRewardsDeductionRate(0, 800_000_000_000_000_000);
    }

    function test_setRewardsDeductionRate_RevertInvalidRate() public {
        staking.addPool(shareTokenA);

        vm.expectRevert("invalid rate");
        staking.setRewardsDeductionRate(0, 1_000_000_000_000_000_001);
    }

    function test_setRewardsDeductionRate_Success() public {
        staking.addPool(shareTokenA);

        assertEq(staking.rewardsDeductionRates(0), 0);
        vm.expectEmit(false, false, false, true);
        emit RewardsDeductionRateSet(0, 800_000_000_000_000_000);
        staking.setRewardsDeductionRate(0, 800_000_000_000_000_000);
        assertEq(staking.rewardsDeductionRates(0), 800_000_000_000_000_000);

        vm.expectEmit(false, false, false, true);
        emit RewardsDeductionRateSet(0, 500_000_000_000_000_000);
        staking.setRewardsDeductionRate(0, 500_000_000_000_000_000);
        assertEq(staking.rewardsDeductionRates(0), 500_000_000_000_000_000);

        vm.expectEmit(false, false, false, true);
        emit RewardsDeductionRateSet(0, 500_000_000_000_000_000);
        staking.setRewardsDeductionRate(0, 500_000_000_000_000_000);
        assertEq(staking.rewardsDeductionRates(0), 500_000_000_000_000_000);
    }

    function test_notifyRewardRule_RevertZeroRewardType() public {
        vm.expectRevert("reward token is zero address");
        staking.notifyRewardRule(0, IERC20(address(0)), 0, 0);
    }

    function test_notifyRewardRule_RevertPoolNotExisted() public {
        vm.expectRevert("pool must be existed");
        staking.notifyRewardRule(0, RewardTokenA, 0, 0);
    }

    function test_notifyRewardRule_RevertZeroDuration() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        vm.expectRevert("zero reward duration");
        staking.notifyRewardRule(0, RewardTokenA, 0, 0);
    }

    function test_notifyRewardRule_SuccessSetZeroRewardAddedWhenStartNewPeriod() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        assertEq(staking.rewardTypes(0).length, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 0);

        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdated(0, RewardTokenA, 0, 1_689_501_000);
        staking.notifyRewardRule(0, RewardTokenA, 0, 1_000);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(address(staking.rewardTypes(0)[0]), address(RewardTokenA));
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 1_689_500_000);
    }

    function test_notifyRewardRule_SuccessStartNewPeriod() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        assertEq(staking.rewardTypes(0).length, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 0);

        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdated(0, RewardTokenA, 5_000, 1_689_501_000);
        staking.notifyRewardRule(0, RewardTokenA, 5_000_000, 1_000);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 5_000);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 1_689_500_000);
    }

    function test_notifyRewardRule_RevertTooManyRewardType() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        assertEq(staking.rewardTypes(0).length, 0);
        staking.notifyRewardRule(0, RewardTokenA, 5_000_000, 1_000);
        assertEq(staking.rewardTypes(0).length, 1);

        staking.notifyRewardRule(0, RewardTokenB, 5_000_000, 2_000);
        assertEq(staking.rewardTypes(0).length, 2);

        staking.notifyRewardRule(0, RewardTokenC, 5_000_000, 3_000);
        assertEq(staking.rewardTypes(0).length, 3);

        vm.expectRevert("too many reward types");
        staking.notifyRewardRule(0, RewardTokenD, 5_000_000, 4_000);
    }

    function test_notifyRewardRule_SuccessStartNewPeriodWhenBeforeRuleExpired() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdated(0, RewardTokenA, 5_000, 1_689_501_000);
        staking.notifyRewardRule(0, RewardTokenA, 5_000_000, 1_000);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 5_000);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // simulate previous rule expired
        vm.warp(1_689_502_000);
        assertEq(block.timestamp, 1_689_502_000);
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdated(0, RewardTokenA, 20_000, 1_689_502_100);
        staking.notifyRewardRule(0, RewardTokenA, 2_000_000, 100);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 20_000);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 1_689_502_100);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 1_689_502_000);
    }

    function test_notifyRewardRule_SuccessOverwritePreviousRule() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdated(0, RewardTokenA, 5_000, 1_689_501_000);
        staking.notifyRewardRule(0, RewardTokenA, 5_000_000, 1_000);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 5_000);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 1_689_500_000);

        vm.warp(1_689_500_500);
        assertEq(block.timestamp, 1_689_500_500);
        assertEq(staking.lastTimeRewardApplicable(0, RewardTokenA), 1_689_500_500);
        assertEq(staking.rewardPerShare(0, RewardTokenA), 0);

        // simulate adjust remaining time, 0 added reward amount
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdated(0, RewardTokenA, 12_500, 1_689_500_700);
        staking.notifyRewardRule(0, RewardTokenA, 0, 200);

        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 12_500);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 1_689_500_700);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 1_689_500_500);
        assertEq(staking.lastTimeRewardApplicable(0, RewardTokenA), 1_689_500_500);
        assertEq(staking.rewardPerShare(0, RewardTokenA), 0);

        // simulate adjust remaining time and 0 added reward amount
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdated(0, RewardTokenA, 30_000, 1_689_500_600);
        staking.notifyRewardRule(0, RewardTokenA, 500_000, 100);

        assertEq(staking.rewardRules(0, RewardTokenA).rewardRate, 30_000);
        assertEq(staking.rewardRules(0, RewardTokenA).endTime, 1_689_500_600);
        assertEq(staking.rewardRules(0, RewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, RewardTokenA).lastAccumulatedTime, 1_689_500_500);
        assertEq(staking.lastTimeRewardApplicable(0, RewardTokenA), 1_689_500_500);
        assertEq(staking.rewardPerShare(0, RewardTokenA), 0);
    }

    function test_stake_RevertZeroAmount() public {
        vm.expectRevert("cannot stake 0");
        staking.stake(0, 0);
    }

    function test_stake_RevertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.stake(0, 100);
    }
}
