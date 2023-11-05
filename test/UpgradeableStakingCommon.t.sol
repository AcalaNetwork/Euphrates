// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/UpgradeableStakingCommon.sol";
import "../src/PoolOperationPausable.sol";

contract UpgradeableStakingCommonTest is Test {
    UpgradeableStakingCommon public staking;
    IERC20 public shareTokenA;
    IERC20 public shareTokenB;
    IERC20 public rewardTokenA;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);

    event NewPool(uint256 poolId, IERC20 shareType);
    event RewardsDeductionRateSet(uint256 poolId, uint256 rate);
    event RewardRuleUpdate(uint256 poolId, IERC20 rewardType, uint256 rewardRate, uint256 endTime);
    event ClaimReward(address indexed account, uint256 poolId, IERC20 indexed rewardType, uint256 amount);
    event Unstake(address indexed account, uint256 poolId, uint256 amount);
    event Stake(address indexed account, uint256 poolId, uint256 amount);

    function setUp() public {
        shareTokenA = new ERC20PresetFixedSupply(
            "ShareTokenA",
            "STA",
            10_000_000,
            ALICE
        );
        shareTokenB = new ERC20PresetFixedSupply(
            "ShareTokenB",
            "STB",
            10_000_000,
            ALICE
        );
        rewardTokenA = new ERC20PresetFixedSupply(
            "rewardTokenA",
            "RTA",
            10_000_000,
            ALICE
        );
        staking = new UpgradeableStakingCommon();
        vm.prank(ADMIN);
        staking.initialize();
    }

    function test_Ownable_works() public {
        assertEq(staking.owner(), ADMIN);

        assertEq(staking.paused(), false);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.pause();

        // only owner can pause
        vm.prank(ADMIN);
        staking.pause();
        assertEq(staking.paused(), true);

        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.unpause();

        // only owner can pause
        vm.prank(ADMIN);
        staking.unpause();
        assertEq(staking.paused(), false);

        assertEq(staking.pausedPoolOperations(0, PoolOperationPausable.Operation.Stake), false);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.setPoolOperationPause(0, PoolOperationPausable.Operation.Stake, true);

        // only owner can set pool operation pause
        vm.prank(ADMIN);
        staking.setPoolOperationPause(0, PoolOperationPausable.Operation.Stake, true);
        assertEq(staking.pausedPoolOperations(0, PoolOperationPausable.Operation.Stake), true);

        assertEq(address(staking.shareTypes(0)), address(0));
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.addPool(shareTokenA);

        // only owner can add pool
        vm.prank(ADMIN);
        staking.addPool(shareTokenA);
        assertEq(address(staking.shareTypes(0)), address(shareTokenA));

        assertEq(staking.rewardsDeductionRates(0), 0);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.unpause();

        // only owner can set rewards deduction rate
        vm.prank(ADMIN);
        staking.setRewardsDeductionRate(0, uint256(1e18) / 10);
        assertEq(staking.rewardsDeductionRates(0), uint256(1e18) / 10);

        assertEq(staking.rewardTypes(0).length, 0);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.updateRewardRule(0, rewardTokenA, 500, block.timestamp + 30 days);

        // only owner can update reward rule
        vm.prank(ALICE);
        rewardTokenA.transfer(ADMIN, 10_000_000);
        vm.startPrank(ADMIN);
        rewardTokenA.approve(address(staking), type(uint256).max);
        staking.updateRewardRule(0, rewardTokenA, 10, block.timestamp + 7 days);
        assertEq(staking.rewardTypes(0).length, 1);
    }

    function test_Pausable_works() public {
        vm.startPrank(ADMIN);

        // pause
        assertEq(staking.paused(), false);
        staking.pause();
        assertEq(staking.paused(), true);

        vm.expectRevert("Pausable: paused");
        staking.setPoolOperationPause(0, PoolOperationPausable.Operation.Stake, true);

        vm.expectRevert("Pausable: paused");
        staking.addPool(shareTokenA);

        vm.expectRevert("Pausable: paused");
        staking.setRewardsDeductionRate(0, 1e18 / 10);

        vm.expectRevert("Pausable: paused");
        staking.updateRewardRule(0, rewardTokenA, 500, block.timestamp + 30 days);

        vm.expectRevert("Pausable: paused");
        staking.stake(0, 1_000_000);

        vm.expectRevert("Pausable: paused");
        staking.unstake(0, 1_000_000);

        vm.expectRevert("Pausable: paused");
        staking.claimRewards(0);

        vm.expectRevert("Pausable: paused");
        staking.exit(0);

        // unpause, then these functions should work
        staking.unpause();
        assertEq(staking.paused(), false);

        staking.setPoolOperationPause(1, PoolOperationPausable.Operation.Stake, true);
        assertEq(staking.pausedPoolOperations(1, PoolOperationPausable.Operation.Stake), true);

        staking.addPool(shareTokenA);
        assertEq(address(staking.shareTypes(0)), address(shareTokenA));

        staking.setRewardsDeductionRate(0, 1e18 / 10);
        assertEq(staking.rewardsDeductionRates(0), 1e18 / 10);
        vm.stopPrank();

        vm.prank(ALICE);
        rewardTokenA.transfer(ADMIN, 10_000_000);
        vm.startPrank(ADMIN);
        rewardTokenA.approve(address(staking), type(uint256).max);
        staking.updateRewardRule(0, rewardTokenA, 10, block.timestamp + 7 days);
        assertEq(staking.rewardTypes(0).length, 1);
        vm.stopPrank();

        vm.startPrank(ALICE);
        shareTokenA.approve(address(staking), 1_000_000);
        staking.stake(0, 1_000_000);
        assertEq(staking.shares(0, ALICE), 1_000_000);

        staking.unstake(0, 500_000);
        assertEq(staking.shares(0, ALICE), 500_000);

        staking.claimRewards(0);

        staking.exit(0);
        assertEq(staking.shares(0, ALICE), 0);
        vm.stopPrank();
    }

    function test_PoolOperationPause_works() public {
        vm.startPrank(ADMIN);
        staking.addPool(shareTokenA);
        staking.addPool(shareTokenB);
        staking.setPoolOperationPause(0, PoolOperationPausable.Operation.Stake, true);
        staking.setPoolOperationPause(1, PoolOperationPausable.Operation.ClaimRewards, true);

        vm.startPrank(ALICE);
        shareTokenA.approve(address(staking), 1_000_000);
        shareTokenB.approve(address(staking), 1_000_000);

        // stake to pool 0 paused
        vm.expectRevert("PoolOperationPausable: operation is paused for this pool");
        staking.stake(0, 1_000_000);

        // stake to pool 1 should work
        staking.stake(1, 1_000_000);
        assertEq(staking.shares(1, ALICE), 1_000_000);

        // unstake from pool 1 should work
        staking.unstake(1, 100_000);
        assertEq(staking.shares(1, ALICE), 900_000);

        // claim rewards from pool 1 paused
        vm.expectRevert("PoolOperationPausable: operation is paused for this pool");
        staking.claimRewards(1);

        // exit from pool 1 should fail for paused claim rewards
        vm.expectRevert("PoolOperationPausable: operation is paused for this pool");
        staking.exit(1);

        vm.startPrank(ADMIN);
        staking.setPoolOperationPause(0, PoolOperationPausable.Operation.Stake, false);
        staking.setPoolOperationPause(1, PoolOperationPausable.Operation.ClaimRewards, false);

        vm.startPrank(ALICE);

        // stake to pool 0 should work
        staking.stake(0, 1_000_000);
        assertEq(staking.shares(0, ALICE), 1_000_000);

        // claim rewards from pool 1 should work
        staking.claimRewards(1);

        // exit from pool 1 should work
        staking.exit(1);
        assertEq(staking.shares(1, ALICE), 0);
    }
}
