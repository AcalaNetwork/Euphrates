// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/Staking.sol";

contract SimpleStaking is Staking {
    constructor() {}
}

contract StakingTest is Test {
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
        shareTokenA = new ERC20PresetFixedSupply(
            "ShareTokenA",
            "STA",
            10_000_000,
            BOB
        );
        shareTokenB = new ERC20PresetFixedSupply(
            "ShareTokenB",
            "STB",
            10_000_000,
            BOB
        );
        rewardTokenA = new ERC20PresetFixedSupply(
            "rewardTokenA",
            "RTA",
            10_000_000,
            ALICE
        );
        rewardTokenB = new ERC20PresetFixedSupply(
            "rewardTokenB",
            "RTB",
            10_000_000,
            ALICE
        );
        rewardTokenC = new ERC20PresetFixedSupply(
            "rewardTokenC",
            "RTC",
            10_000_000,
            ALICE
        );
        rewardTokenD = new ERC20PresetFixedSupply(
            "rewardTokenD",
            "RTD",
            10_000_000,
            ALICE
        );
    }

    function test_addPool_revertZeroShareType() public {
        vm.expectRevert("share token is zero address");
        staking.addPool(IERC20(address(0)));
    }

    function test_addPool_works() public {
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

    function test_setRewardsDeductionRate_revertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.setRewardsDeductionRate(0, 800_000_000_000_000_000);
    }

    function test_setRewardsDeductionRate_revertInvalidRate() public {
        staking.addPool(shareTokenA);

        vm.expectRevert("invalid rate");
        staking.setRewardsDeductionRate(0, 1_000_000_000_000_000_001);
    }

    function test_setRewardsDeductionRate_works() public {
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

    function test_updateRewardRule_revertZeroRewardType() public {
        vm.expectRevert("reward token is zero address");
        staking.updateRewardRule(0, IERC20(address(0)), 0, 0);
    }

    function test_updateRewardRule_revertPoolNotExisted() public {
        vm.expectRevert("pool must be existed");
        staking.updateRewardRule(0, rewardTokenA, 0, 0);
    }

    function test_updateRewardRule_works() public {
        address admin = address(this);
        staking.addPool(shareTokenA);
        vm.prank(ALICE);
        rewardTokenA.transfer(admin, 10_000);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        assertEq(staking.rewardTypes(0).length, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 0);
        assertEq(rewardTokenA.balanceOf(admin), 10_000);
        assertEq(rewardTokenA.balanceOf(address(staking)), 0);

        // transferFrom reward need allowance
        vm.expectRevert("ERC20: insufficient allowance");
        staking.updateRewardRule(0, rewardTokenA, 5, 1_689_501_000);

        rewardTokenA.approve(address(staking), type(uint256).max);

        // start a new reward rule, transfer reward from admin to staking contract
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 5, 1_689_501_000);
        staking.updateRewardRule(0, rewardTokenA, 5, 1_689_501_000);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(address(staking.rewardTypes(0)[0]), address(rewardTokenA));
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 5);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_000);
        assertEq(rewardTokenA.balanceOf(admin), 5_000);
        assertEq(rewardTokenA.balanceOf(address(staking)), 5_000);

        vm.warp(1_689_500_500);

        // increase the rewardRate for existed rule, transfer the reward gap from admin to staking contract
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 10, 1_689_501_000);
        staking.updateRewardRule(0, rewardTokenA, 10, 1_689_501_000);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(address(staking.rewardTypes(0)[0]), address(rewardTokenA));
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 10);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_500);
        assertEq(rewardTokenA.balanceOf(admin), 2_500);
        assertEq(rewardTokenA.balanceOf(address(staking)), 7_500);

        vm.warp(1_689_500_800);

        // decrease the rewardRate for existed rule, the surplus reward refund to admin.
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 8, 1_689_501_000);
        staking.updateRewardRule(0, rewardTokenA, 8, 1_689_501_000);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(address(staking.rewardTypes(0)[0]), address(rewardTokenA));
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 8);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_501_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_800);
        assertEq(rewardTokenA.balanceOf(admin), 2_900);
        assertEq(rewardTokenA.balanceOf(address(staking)), 7_100);

        // update the endTime less than block.timestamp, is equal to end the current reward rule, will refund the remainer reward.
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 10, 1_689_500_800);
        staking.updateRewardRule(0, rewardTokenA, 10, 1_689_500_400);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(address(staking.rewardTypes(0)[0]), address(rewardTokenA));
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 10);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_500_800);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_500_800);
        assertEq(rewardTokenA.balanceOf(admin), 4_500);
        assertEq(rewardTokenA.balanceOf(address(staking)), 5_500);

        vm.warp(1_689_501_000);

        // restart rule
        vm.expectEmit(false, false, false, true);
        emit RewardRuleUpdate(0, rewardTokenA, 5, 1_689_501_200);
        staking.updateRewardRule(0, rewardTokenA, 5, 1_689_501_200);
        assertEq(staking.rewardTypes(0).length, 1);
        assertEq(address(staking.rewardTypes(0)[0]), address(rewardTokenA));
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 5);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_501_200);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);
        assertEq(rewardTokenA.balanceOf(admin), 3_500);
        assertEq(rewardTokenA.balanceOf(address(staking)), 6_500);
    }

    function test_updateRewardRule_revertTooManyRewardType() public {
        vm.startPrank(ALICE);
        rewardTokenA.transfer(address(this), 10_000_000);
        rewardTokenB.transfer(address(this), 10_000_000);
        rewardTokenC.transfer(address(this), 10_000_000);
        rewardTokenD.transfer(address(this), 10_000_000);
        vm.stopPrank();

        staking.addPool(shareTokenA);
        rewardTokenA.approve(address(staking), type(uint256).max);
        rewardTokenB.approve(address(staking), type(uint256).max);
        rewardTokenC.approve(address(staking), type(uint256).max);
        rewardTokenD.approve(address(staking), type(uint256).max);

        vm.warp(1_689_500_000);
        assertEq(block.timestamp, 1_689_500_000);

        assertEq(staking.rewardTypes(0).length, 0);
        staking.updateRewardRule(0, rewardTokenA, 500, 1_689_501_000);
        assertEq(staking.rewardTypes(0).length, 1);

        staking.updateRewardRule(0, rewardTokenB, 500, 1_689_502_000);
        assertEq(staking.rewardTypes(0).length, 2);

        staking.updateRewardRule(0, rewardTokenC, 500, 1_689_503_000);
        assertEq(staking.rewardTypes(0).length, 3);

        vm.expectRevert("too many reward types");
        staking.updateRewardRule(0, rewardTokenD, 500, 1_689_504_000);
    }

    function test_stake_revertZeroAmount() public {
        vm.expectRevert("cannot stake 0");
        staking.stake(0, 0);
    }

    function test_stake_revertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.stake(0, 100);
    }

    function test_stake_withNoRewardRule() public {
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

    function test_stake_rewardRuleAfterStake() public {
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
        rewardTokenA.transfer(address(this), 5_000_000);
        rewardTokenA.approve(address(staking), 5_000_000);
        staking.updateRewardRule(0, rewardTokenA, 2_500, 1_689_503_000);
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
        assertEq(staking.rewardPerShare(0, rewardTokenA), (2_500 * 500 * 1e18) / 1_000_000);
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
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), (2_500 * 500 * 1e18) / 1_000_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), (2_500 * 500 * 1e18) / 1_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, (2_500 * 500 * 1e18) / 1_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_500);

        // simulate 500 seconds passed, reward has accumulated to pending
        vm.warp(1_689_502_000);
        assertEq(staking.earned(0, BOB, rewardTokenA), 1_250_000 + 416_666);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), 0);
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 833_333);
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), (2_500 * 500 * 1e18) / 1_000_000);
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, (2_500 * 500 * 1e18) / 1_000_000);
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
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
        );
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 833_333);
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), (2_500 * 500 * 1e18) / 1_000_000);
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_502_000);

        // simulate 2000 seconds passed, actually the reward acclumated ended at 1_689_503_000
        vm.warp(1_689_504_000);

        assertEq(staking.earned(0, BOB, rewardTokenA), 1_250_000 + 416_666 + 1_250_000);
        assertEq(staking.rewards(0, BOB, rewardTokenA), 1_250_000 + 416_666);
        assertEq(
            staking.paidAccumulatedRates(0, BOB, rewardTokenA),
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
        );
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 833_333 + 1_250_000);
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), (2_500 * 500 * 1e18) / 1_000_000);
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
                + ((2_500 * 1_000 * 1e18) / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
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
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
                + ((2_500 * 1_000 * 1e18) / 4_000_000)
        );
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
                + ((2_500 * 1_000 * 1e18) / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_503_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            ((uint256(2_500) * 500 * 1e18) / 3_000_000) + ((2_500 * 500 * 1e18) / 1_000_000)
                + ((2_500 * 1_000 * 1e18) / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_503_000);
    }

    function test_unstake_revertZeroAmount() public {
        vm.expectRevert("cannot unstake 0");
        staking.unstake(0, 0);
    }

    function test_unstake_revertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.unstake(0, 100);
    }

    function test_unstake_revertNotEnoughShares() public {
        staking.addPool(shareTokenA);
        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 1_000_000);
        staking.stake(0, 1_000_000);

        assertEq(staking.totalShares(0), 1_000_000);
        assertEq(staking.shares(0, BOB), 1_000_000);

        vm.expectRevert("share not enough");
        staking.unstake(0, 1_000_001);
    }

    function test_unstake_hasRewardRule() public {
        vm.warp(1_689_500_000);
        staking.addPool(shareTokenA);

        vm.prank(ALICE);
        rewardTokenA.transfer(address(this), 5_000_000);
        rewardTokenA.approve(address(staking), 5_000_000);
        staking.updateRewardRule(0, rewardTokenA, 2_500, 1_689_502_000);

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
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 1_500_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 1_500_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, (uint256(2_500) * 1000 * 1e18) / 1_500_000);
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
            ((uint256(2_500) * 1000 * 1e18) / 1_500_000) + ((uint256(2_500) * 1000 * 1e18) / 1_000_000)
        );
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            ((uint256(2_500) * 1000 * 1e18) / 1_500_000) + ((uint256(2_500) * 1000 * 1e18) / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            ((uint256(2_500) * 1000 * 1e18) / 1_500_000) + ((uint256(2_500) * 1000 * 1e18) / 1_000_000)
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
            ((uint256(2_500) * 1000 * 1e18) / 1_500_000) + ((uint256(2_500) * 1000 * 1e18) / 1_000_000)
        );
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            ((uint256(2_500) * 1000 * 1e18) / 1_500_000) + ((uint256(2_500) * 1000 * 1e18) / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            ((uint256(2_500) * 1000 * 1e18) / 1_500_000) + ((uint256(2_500) * 1000 * 1e18) / 1_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_502_000);
    }

    function test_claimRewards_withoutDeduction() public {
        vm.warp(1_689_500_000);
        staking.addPool(shareTokenA);

        vm.prank(ALICE);
        rewardTokenA.transfer(address(this), 5_000_000);
        rewardTokenA.approve(address(staking), 5_000_000);
        staking.updateRewardRule(0, rewardTokenA, 2_500, 1_689_502_000);

        vm.startPrank(BOB);
        shareTokenA.approve(address(staking), 2_000_000);
        staking.stake(0, 2_000_000);
        vm.stopPrank();

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
        assertEq(staking.rewardPerShare(0, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
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
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);
    }

    function test_claimRewards_withDeduction() public {
        vm.warp(1_689_500_000);
        staking.addPool(shareTokenA);

        vm.prank(ALICE);
        rewardTokenA.transfer(address(this), 5_000_000);
        rewardTokenA.approve(address(staking), 5_000_000);
        staking.updateRewardRule(0, rewardTokenA, 2_500, 1_689_502_000);
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
        assertEq(staking.rewardPerShare(0, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
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
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, (uint256(2_500) * 1000 * 1e18) / 2_000_000);
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
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.shares(0, CHARLIE), 2_000_000);
        assertEq(staking.earned(0, CHARLIE, rewardTokenA), 250_000); // CHARLIE also get redistribution
        assertEq(staking.rewards(0, CHARLIE, rewardTokenA), 0);
        assertEq(staking.paidAccumulatedRates(0, CHARLIE, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(
            staking.rewardPerShare(0, rewardTokenA),
            ((uint256(2_500) * 1000 * 1e18) / 2_000_000) + ((500_000 * 1e18) / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(
            staking.rewardRules(0, rewardTokenA).rewardRateAccumulated,
            ((uint256(2_500) * 1000 * 1e18) / 2_000_000) + ((500_000 * 1e18) / 4_000_000)
        );
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);
    }

    function test_exit_works() public {
        vm.warp(1_689_500_000);
        staking.addPool(shareTokenA);

        vm.prank(ALICE);
        rewardTokenA.transfer(address(this), 5_000_000);
        rewardTokenA.approve(address(staking), 5_000_000);
        staking.updateRewardRule(0, rewardTokenA, 2_500, 1_689_502_000);

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
        assertEq(staking.rewardPerShare(0, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
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
        assertEq(staking.paidAccumulatedRates(0, BOB, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.rewardPerShare(0, rewardTokenA), (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRate, 2_500);
        assertEq(staking.rewardRules(0, rewardTokenA).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, rewardTokenA).rewardRateAccumulated, (uint256(2_500) * 1000 * 1e18) / 2_000_000);
        assertEq(staking.rewardRules(0, rewardTokenA).lastAccumulatedTime, 1_689_501_000);
    }
}
