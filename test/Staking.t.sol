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
    IERC20 public rewardTokenA;
    IERC20 public rewardTokenB;
    IERC20 public rewardTokenC;
    IERC20 public rewardTokenD;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);
    address public CHARLIE = address(0x3333);
    address public DAVE = address(0x4444);

    event NewPool(uint256 poolId, IERC20 shareType);
    event RewardsDeductionRateSet(uint256 poolId, uint256 rate);
    event RewardRuleUpdate(uint256 poolId, IERC20 rewardType, uint256 rewardRate, uint256 endTime);
    event ClaimReward(address indexed account, uint256 poolId, IERC20 indexed rewardType, uint256 amount);
    event Unstake(address indexed account, uint256 poolId, uint256 amount);
    event Stake(address indexed account, uint256 poolId, uint256 amount);

    function setUp() public {
        staking = new SimpleStaking();
        shareTokenA = new ERC20PresetFixedSupply("ShareTokenA", "STA", 10_000_000, BOB);
        shareTokenB = new ERC20PresetFixedSupply("ShareTokenB", "STB", 10_000_000, BOB);
        rewardTokenA = new ERC20PresetFixedSupply("rewardTokenA", "RTA", 10_000_000, ALICE);
        rewardTokenB = new ERC20PresetFixedSupply("rewardTokenB", "RTB", 10_000_000, ALICE);
        rewardTokenC = new ERC20PresetFixedSupply("rewardTokenC", "RTC", 10_000_000, ALICE);
        rewardTokenD = new ERC20PresetFixedSupply("rewardTokenD", "RTD", 10_000_000, ALICE);
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
        staking.notifyRewardRule(0, rewardTokenA, 0, 0);
    }

    function test_notifyRewardRule_RevertZeroDuration() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        vm.expectRevert("zero reward duration");
        staking.notifyRewardRule(0, rewardTokenA, 0, 0);
    }

    function test_notifyRewardRule_SuccessSetZeroRewardAddedWhenStartNewPeriod() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        assertEq(staking.rewardTypes(0).length, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 0);

        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 0, 1_689_501_000);
        staking.notifyRewardRule(0, rewardTokenA, 0, 1_000);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(address(staking.rewardTypes(0)[0]), address(rewardTokenA));
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);
    }

    function test_notifyRewardRule_SuccessStartNewPeriod() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        assertEq(staking.rewardTypes(0).length, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 0);

        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 5_000, 1_689_501_000);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 1_000);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 5_000);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);
    }

    function test_notifyRewardRule_RevertTooManyRewardType() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        assertEq(staking.rewardTypes(0).length, 0);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 1_000);
        assertEq(staking.rewardTypes(0).length, 1);

        staking.notifyRewardRule(0, rewardTokenB, 5_000_000, 2_000);
        assertEq(staking.rewardTypes(0).length, 2);

        staking.notifyRewardRule(0, rewardTokenC, 5_000_000, 3_000);
        assertEq(staking.rewardTypes(0).length, 3);

        vm.expectRevert("too many reward types");
        staking.notifyRewardRule(0, rewardTokenD, 5_000_000, 4_000);
    }

    function test_notifyRewardRule_SuccessStartNewPeriodWhenBeforeRuleExpired() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 5_000, 1_689_501_000);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 1_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 5_000);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // simulate previous rule expired
        vm.warp(1_689_502_000);
        assertEq(block.timestamp, 1_689_502_000);
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 20_000, 1_689_502_100);
        staking.notifyRewardRule(0, rewardTokenA, 2_000_000, 100);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 20_000);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_100);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_502_000);
    }

    function test_notifyRewardRule_SuccessOverwritePreviousRule() public {
        staking.addPool(shareTokenA);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 5_000, 1_689_501_000);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 1_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 5_000);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        vm.warp(1_689_500_500);
        assertEq(block.timestamp, 1_689_500_500);
        assertEq(staking.lastTimeRewardApplicable(0, rewardTokenA), 1_689_500_500);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 0);

        // simulate adjust remaining time, 0 added reward amount
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 12_500, 1_689_500_700);
        staking.notifyRewardRule(0, rewardTokenA, 0, 200);

        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 12_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_500_700);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_500);
        assertEq(staking.lastTimeRewardApplicable(0, rewardTokenA), 1_689_500_500);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 0);

        // simulate adjust remaining time and 0 added reward amount
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 30_000, 1_689_500_600);
        staking.notifyRewardRule(0, rewardTokenA, 500_000, 100);

        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 30_000);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_500_600);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_500);
        assertEq(staking.lastTimeRewardApplicable(0, rewardTokenA), 1_689_500_500);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 0);
    }

    function test_stake_RevertZeroAmount() public {
        vm.expectRevert("cannot stake 0");
        staking.stake(0, 0);
    }

    function test_stake_RevertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.stake(0, 100);
    }

    function test_stake_SuccessWithNoRewardRule() public {
        staking.addPool(shareTokenA);

        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 1_000_000);

        assertEq(shareTokenA.balanceOf(address(staking)), 0);
        assertEq(shareTokenA.balanceOf(BOB), 10_000_000);
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, BOB), 0);

        // BOB stakes share
        vm.expectEmit(true, false, false, true);
        emit Stake(BOB, 0, 1_000_000);
        staking.stake(0, 1_000_000);

        assertEq(shareTokenA.balanceOf(address(staking)), 1_000_000);
        assertEq(shareTokenA.balanceOf(BOB), 10_000_000 - 1_000_000);
        assertEq(staking.totalShares(0), 1_000_000);
        assertEq(staking.shares(0, BOB), 1_000_000);

        shareTokenA.transfer(CHARLIE, 2_000_000);
        vm.startPrank(CHARLIE);
        shareTokenA.approve(address(staking), 2_000_000);

        assertEq(shareTokenA.balanceOf(CHARLIE), 2_000_000);
        assertEq(staking.shares(0, CHARLIE), 0);

        // CHARLIE stakes share
        vm.expectEmit(true, false, false, true);
        emit Stake(CHARLIE, 0, 2_000_000);
        staking.stake(0, 2_000_000);

        assertEq(shareTokenA.balanceOf(address(staking)), 3_000_000);
        assertEq(shareTokenA.balanceOf(CHARLIE), 0);
        assertEq(staking.totalShares(0), 3_000_000);
        assertEq(staking.shares(0, CHARLIE), 2_000_000);
        vm.stopPrank();
    }

    function test_stake_SuccessRewardRuleAfterStake() public {
        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);
        staking.addPool(shareTokenA);

        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 1_000_000);
        shareTokenA.transfer(CHARLIE, 2_000_000);
        shareTokenA.transfer(DAVE, 2_000_000);
        vm.stopPrank();

        assertEq(shareTokenA.balanceOf(address(staking)), 0);
        assertEq(shareTokenA.balanceOf(BOB), 6_000_000);
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, BOB), 0);

        // there's no reward rules, BOB stakes share
        vm.expectEmit(true, false, false, true);
        emit Stake(BOB, 0, 1_000_000);
        vm.prank(BOB);
        staking.stake(0, 1_000_000);

        assertEq(shareTokenA.balanceOf(address(staking)), 1_000_000);
        assertEq(shareTokenA.balanceOf(BOB), 5_000_000);
        assertEq(staking.totalShares(0), 1_000_000);
        assertEq(staking.shares(0, BOB), 1_000_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 0);

        // then, add new reward rule
        vm.warp(1_689_501_000);
        assertEq(block.timestamp, 1_689_501_000);
        vm.prank(ALICE);
        rewardTokenA.transfer(address(staking), 5_000_000);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 2_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);

        // no time passed, rewardPerShare has no change
        assertEq(staking.rewardPerShare(0, rewardTokenA), 0);
        assertEq(staking.earned(0, BOB, rewardTokenA), 0);

        // simulate 500 seconds passed, reward has accumulated to pending
        vm.warp(1_689_501_500);
        assertEq(staking.earned(0, BOB, rewardTokenA), 1_250_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 2_500 * 500 * 1e18 / 1_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);

        // CHARLIE stakes share, reward will distribute, rewardRule will update
        vm.startPrank(CHARLIE);
        shareTokenA.approve(address(staking), 2_000_000);
        staking.stake(0, 2_000_000);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 3_000_000);
        assertEq(staking.shares(0, BOB), 1_000_000);
        assertEq(staking.shares(0, CHARLIE), 2_000_000);

        assertEq(staking.earned(0, BOB, rewardTokenA), 1_250_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), 2_500 * 500 * 1e18 / 1_000_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 2_500 * 500 * 1e18 / 1_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 2_500 * 500 * 1e18 / 1_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_500);

        // simulate 500 seconds passed, reward has accumulated to pending
        vm.warp(1_689_502_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 1_250_000 + 416_666);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 833_333);
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), 2_500 * 500 * 1e18 / 1_000_000);
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 2_500 * 500 * 1e18 / 1_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_500);

        // BOB stake more share, will distribute pending rewards which accumlated before
        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 1_000_000);
        staking.stake(0, 1_000_000);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 4_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.shares(0, CHARLIE), 2_000_000);

        assertEq(staking.earned(0, BOB, rewardTokenA), 1_250_000 + 416_666);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 1_250_000 + 416_666);
        assertEq(
            staking.paidAccumulatedRates(0, BOB, rewardTokenA),
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
        );
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 833_333);
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), 2_500 * 500 * 1e18 / 1_000_000);
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_502_000);

        // simulate 2000 seconds passed, actually the reward acclumated ended at 1_689_503_000
        vm.warp(1_689_504_000);

        assertEq(staking.earned(0, BOB, rewardTokenA), 1_250_000 + 416_666 + 1_250_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 1_250_000 + 416_666);
        assertEq(
            staking.paidAccumulatedRates(0, BOB, rewardTokenA),
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
        );
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 833_333 + 1_250_000);
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), 2_500 * 500 * 1e18 / 1_000_000);
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
                + (2_500 * 1_000 * 1e18 / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_502_000);

        // reward accumulate ended, DAVE stake just trigger reward distribution
        vm.startPrank(DAVE);
        shareTokenA.approve(address(staking), 1_000_000);
        staking.stake(0, 1_000_000);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 5_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.shares(0, CHARLIE), 2_000_000);
        assertEq(staking.shares(0, DAVE), 1_000_000);
        assertEq(staking.earned(0, DAVE, rewardTokenA), 0);
        assertEq(staking.rewards(0, DAVE, rewardTokenA), 0);
        assertEq(
            staking.paidAccumulatedRates(0, DAVE, rewardTokenA),
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
                + (2_500 * 1_000 * 1e18 / 4_000_000)
        );
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
                + (2_500 * 1_000 * 1e18 / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            (uint256(2_500) * 500 * 1e18 / 3_000_000) + (2_500 * 500 * 1e18 / 1_000_000)
                + (2_500 * 1_000 * 1e18 / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_503_000);
    }

    function test_unstake_RevertZeroAmount() public {
        vm.expectRevert("cannot unstake 0");
        staking.unstake(0, 0);
    }

    function test_unstake_RevertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.unstake(0, 100);
    }

    function test_unstake_RevertNotEnoughShares() public {
        staking.addPool(shareTokenA);
        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 1_000_000);
        staking.stake(0, 1_000_000);

        assertEq(staking.totalShares(0), 1_000_000);
        assertEq(staking.shares(0, BOB), 1_000_000);

        vm.expectRevert("share not enough");
        staking.unstake(0, 1_000_001);
    }

    function test_unstake_SuccessHasRewardRule() public {
        vm.warp(1_689_500_000);
        staking.addPool(shareTokenA);

        vm.prank(ALICE);
        rewardTokenA.transfer(address(staking), 5_000_000);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 2_000);

        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 2_000_000);
        staking.stake(0, 2_000_000);

        assertEq(staking.totalShares(0), 2_000_000);
        assertEq(shareTokenA.balanceOf(address(staking)), 2_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(shareTokenA.balanceOf(BOB), 8_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // unstake, no earned, reward rule updated
        vm.expectEmit(true, false, false, true);
        emit Unstake(BOB, 0, 500_000);
        staking.unstake(0, 500_000);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 1_500_000);
        assertEq(shareTokenA.balanceOf(address(staking)), 1_500_000);
        assertEq(staking.shares(0, BOB), 1_500_000);
        assertEq(shareTokenA.balanceOf(BOB), 8_500_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // simulate 1000 seconds passed, BOB unstake, reward will accumulate and distribute
        vm.warp(1_689_501_000);
        vm.prank(BOB);
        vm.expectEmit(true, false, false, true);
        emit Unstake(BOB, 0, 500_000);
        staking.unstake(0, 500_000);
        assertEq(staking.totalShares(0), 1_000_000);
        assertEq(shareTokenA.balanceOf(address(staking)), 1_000_000);
        assertEq(staking.shares(0, BOB), 1_000_000);
        assertEq(shareTokenA.balanceOf(BOB), 9_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 2_499_999);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 2_499_999);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 1_500_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 1_500_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, uint256(2_500) * 1000 * 1e18 / 1_500_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);

        // simulate 2000 seconds passed, reward ends, BOB unstake, reward will accumulate and distribute
        vm.warp(1_689_503_000);
        vm.prank(BOB);
        vm.expectEmit(true, false, false, true);
        emit Unstake(BOB, 0, 800_000);
        staking.unstake(0, 800_000);
        assertEq(staking.totalShares(0), 200_000);
        assertEq(shareTokenA.balanceOf(address(staking)), 200_000);
        assertEq(staking.shares(0, BOB), 200_000);
        assertEq(shareTokenA.balanceOf(BOB), 9_800_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 4_999_999);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 4_999_999);
        assertEq(
            staking.paidAccumulatedRates(0, BOB, rewardTokenA),
            (uint256(2_500) * 1000 * 1e18 / 1_500_000) + (uint256(2_500) * 1000 * 1e18 / 1_000_000)
        );
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            (uint256(2_500) * 1000 * 1e18 / 1_500_000) + (uint256(2_500) * 1000 * 1e18 / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            (uint256(2_500) * 1000 * 1e18 / 1_500_000) + (uint256(2_500) * 1000 * 1e18 / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_502_000);

        // BOB unstake all remaining share, reward already ended, reward rule will not change
        vm.prank(BOB);
        vm.expectEmit(true, false, false, true);
        emit Unstake(BOB, 0, 200_000);
        staking.unstake(0, 200_000);
        assertEq(staking.totalShares(0), 0);
        assertEq(shareTokenA.balanceOf(address(staking)), 0);
        assertEq(staking.shares(0, BOB), 0);
        assertEq(shareTokenA.balanceOf(BOB), 10_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 4_999_999);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 4_999_999);
        assertEq(
            staking.paidAccumulatedRates(0, BOB, rewardTokenA),
            (uint256(2_500) * 1000 * 1e18 / 1_500_000) + (uint256(2_500) * 1000 * 1e18 / 1_000_000)
        );
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            (uint256(2_500) * 1000 * 1e18 / 1_500_000) + (uint256(2_500) * 1000 * 1e18 / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            (uint256(2_500) * 1000 * 1e18 / 1_500_000) + (uint256(2_500) * 1000 * 1e18 / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_502_000);
    }

    function test_claimRewards_SuccessWithoutDeduction() public {
        vm.warp(1_689_500_000);
        staking.addPool(shareTokenA);

        vm.prank(ALICE);
        rewardTokenA.transfer(address(staking), 5_000_000);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 2_000);

        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 2_000_000);
        staking.stake(0, 2_000_000);

        assertEq(rewardTokenA.balanceOf(address(staking)), 5_000_000);
        assertEq(rewardTokenA.balanceOf(BOB), 0);
        assertEq(staking.totalShares(0), 2_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // simulate 1000 seconds passed, BOB accumulate reward to pending
        vm.warp(1_689_501_000);

        assertEq(rewardTokenA.balanceOf(address(staking)), 5_000_000);
        assertEq(rewardTokenA.balanceOf(BOB), 0);
        assertEq(staking.totalShares(0), 2_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 2_500_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardPerShare(0, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // BOB claim reward, distribute pending reward and reward rule updated
        vm.prank(BOB);
        vm.expectEmit(true, false, true, true);
        emit ClaimReward(BOB, 0, rewardTokenA, 2_500_000);
        staking.claimRewards(0);

        assertEq(rewardTokenA.balanceOf(address(staking)), 2_500_000);
        assertEq(rewardTokenA.balanceOf(BOB), 2_500_000);
        assertEq(staking.totalShares(0), 2_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);
    }

    function test_claimRewards_SuccessWithDeduction() public {
        vm.warp(1_689_500_000);
        staking.addPool(shareTokenA);

        vm.prank(ALICE);
        rewardTokenA.transfer(address(staking), 5_000_000);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 2_000);
        staking.setRewardsDeductionRate(0, 200_000_000_000_000_000); // 20%

        vm.startPrank(BOB);
        shareTokenA.transfer(CHARLIE, 2_000_000);
        shareTokenA.approve(address(staking), 2_000_000);
        staking.stake(0, 2_000_000);
        vm.stopPrank();

        // simulate 1000 seconds passed, BOB accumulate reward to pending
        vm.warp(1_689_501_000);

        assertEq(rewardTokenA.balanceOf(address(staking)), 5_000_000);
        assertEq(rewardTokenA.balanceOf(BOB), 0);
        assertEq(staking.totalShares(0), 2_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 2_500_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardPerShare(0, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // CHARLIE stake
        vm.startPrank(CHARLIE);
        shareTokenA.approve(address(staking), 2_000_000);
        staking.stake(0, 2_000_000);
        vm.stopPrank();

        assertEq(rewardTokenA.balanceOf(address(staking)), 5_000_000);
        assertEq(rewardTokenA.balanceOf(BOB), 0);
        assertEq(staking.totalShares(0), 4_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 2_500_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.shares(0, CHARLIE), 2_000_000);
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);

        // BOB claim reward with 20% deduction, and the deduction redistribute to all stakers
        vm.prank(BOB);
        vm.expectEmit(true, false, true, true);
        emit ClaimReward(BOB, 0, rewardTokenA, 2_000_000);
        staking.claimRewards(0);

        assertEq(rewardTokenA.balanceOf(address(staking)), 3_000_000);
        assertEq(rewardTokenA.balanceOf(BOB), 2_000_000);
        assertEq(staking.totalShares(0), 4_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 250_000); // from deduction redistributed
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.shares(0, CHARLIE), 2_000_000);
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 250_000); // CHARLIE also get redistribution
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            (uint256(2_500) * 1000 * 1e18 / 2_000_000) + (500_000 * 1e18 / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            (uint256(2_500) * 1000 * 1e18 / 2_000_000) + (500_000 * 1e18 / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);
    }

    function test_exit_Success() public {
        vm.warp(1_689_500_000);
        staking.addPool(shareTokenA);

        vm.prank(ALICE);
        rewardTokenA.transfer(address(staking), 5_000_000);
        staking.notifyRewardRule(0, rewardTokenA, 5_000_000, 2_000);

        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 2_000_000);
        staking.stake(0, 2_000_000);
        vm.stopPrank();

        assertEq(shareTokenA.balanceOf(address(staking)), 2_000_000);
        assertEq(shareTokenA.balanceOf(BOB), 8_000_000);
        assertEq(rewardTokenA.balanceOf(address(staking)), 5_000_000);
        assertEq(rewardTokenA.balanceOf(BOB), 0);
        assertEq(staking.totalShares(0), 2_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardPerShare(0, rewardTokenA), 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // simulate 1000 seconds passed, BOB accumulate reward to pending
        vm.warp(1_689_501_000);

        assertEq(shareTokenA.balanceOf(address(staking)), 2_000_000);
        assertEq(shareTokenA.balanceOf(BOB), 8_000_000);
        assertEq(rewardTokenA.balanceOf(address(staking)), 5_000_000);
        assertEq(rewardTokenA.balanceOf(BOB), 0);
        assertEq(staking.totalShares(0), 2_000_000);
        assertEq(staking.shares(0, BOB), 2_000_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 2_500_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewardPerShare(0, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);

        // BOB exit will unstake all shares and claim rewards
        vm.prank(BOB);
        vm.expectEmit(true, false, true, true);
        emit Unstake(BOB, 0, 2_000_000);
        emit ClaimReward(BOB, 0, rewardTokenA, 2_500_000);
        staking.exit(0);

        assertEq(shareTokenA.balanceOf(address(staking)), 0);
        assertEq(shareTokenA.balanceOf(BOB), 10_000_000);
        assertEq(rewardTokenA.balanceOf(address(staking)), 2_500_000);
        assertEq(rewardTokenA.balanceOf(BOB), 2_500_000);
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, BOB), 0);
        assertEq(staking.earned(0, BOB, rewardTokenA), 0);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, uint256(2_500) * 1000 * 1e18 / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);
    }
}
