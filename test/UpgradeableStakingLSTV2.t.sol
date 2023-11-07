// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/UpgradeableStakingLSTV2.sol";
import "../src/WrappedTDOT.sol";
import "./MockHoma.sol";
import "./MockLiquidCrowdloan.sol";
import "./MockStableAsset.sol";
import "./MockToken.sol";

contract UpgradeableStakingLSTV2Test is Test {
    using stdStorage for StdStorage;

    event LSTPoolConverted(
        uint256 poolId,
        IERC20 beforeShareType,
        IERC20 afterShareType,
        uint256 beforeShareTokenAmount,
        uint256 afterShareTokenAmount
    );
    event Unstake(address indexed account, uint256 poolId, uint256 amount);
    event Stake(address indexed account, uint256 poolId, uint256 amount);
    event ClaimReward(address indexed account, uint256 poolId, IERC20 indexed rewardType, uint256 amount);

    UpgradeableStakingLSTV2 public staking;
    MockHoma public homa;
    MockStableAsset public stableAsset;
    MockLiquidCrowdloan public liquidCrowdloan;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;
    WrappedTDOT public wtdot;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);
    address public BOB = address(0x3333);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        lcdot = IERC20(address(new MockToken("Acala LcDOT", "LcDOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether)));
        tdot = IERC20(address(new MockToken("Acala tDOT", "tDOT", 1_000_000_000 ether)));

        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAsset(
            address(dot),
            address(ldot),
            address(tdot),
            address(homa)
        );
        liquidCrowdloan = new MockLiquidCrowdloan(
            address(lcdot),
            address(dot),
            1e18
        );
        wtdot = new WrappedTDOT(address(tdot));

        staking = new UpgradeableStakingLSTV2();
        vm.prank(ADMIN);
        staking.initialize(
            address(dot),
            address(lcdot),
            address(ldot),
            address(tdot),
            address(homa),
            address(stableAsset),
            address(liquidCrowdloan),
            address(wtdot)
        );
    }

    function test_stakeTo_revertZeroReceiver() public {
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        vm.expectRevert("invalid receiver");
        staking.stakeTo(0, 0, address(0));
    }

    function test_stakeTo_revertZeroAmount() public {
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        vm.expectRevert("cannot stake 0");
        staking.stakeTo(0, 0, ALICE);
    }

    function test_stakeTo_revertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.stakeTo(0, 100, ALICE);
    }

    function test_stakeTo_works() public {
        vm.warp(1_689_500_000);

        dot.transfer(ADMIN, 1_000_000 ether);
        lcdot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        dot.approve(address(staking), 1_000_000 ether);
        staking.updateRewardRule(0, dot, 500 ether, 1_689_502_000);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(staking.shares(0, BOB), 0);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE add share to BOB at pool#0, which hasn't been converted yet.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 200_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(BOB, 0, 200_000 ether);
        staking.stakeTo(0, 200_000 ether, BOB);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 200_000 ether);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(staking.shares(0, BOB), 200_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 200_000 ether);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.earned(0, BOB, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, BOB, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // convert pool#0 to LDOT
        vm.warp(1_689_501_000);
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, ldot, 200_000 ether, 1_600_000 ether);
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
        assertEq(staking.totalShares(0), 200_000 ether);
        assertEq(staking.shares(0, BOB), 200_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 1_600_000 ether);
        assertEq(staking.rewards(0, BOB, dot), 0);
        assertEq(staking.earned(0, BOB, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, BOB, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE stake LCDOT to BOB at pool#0 after conversion, now the liquidCrowdloan redeem token is still DOT.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 500_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(BOB, 0, 500_000 ether);
        staking.stakeTo(0, 500_000 ether, BOB);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 700_000 ether);
        assertEq(staking.shares(0, BOB), 700_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 5_600_000 ether);
        assertEq(staking.rewards(0, BOB, dot), 500_000 ether);
        assertEq(staking.earned(0, BOB, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, BOB, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // simulate the exchange rate of LDOT to DOT from 8:1 increases to 5:1
        stdstore.target(address(homa)).sig("getExchangeRate()").checked_write(1e18 / 5);
        assertEq(homa.getExchangeRate(), 1e18 / 5);

        // ALICE stake more LCDOT to BOB at pool#0, but get less share amount than before.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 100_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(BOB, 0, 62_500 ether);
        staking.stakeTo(0, 100_000 ether, BOB);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 762_500 ether);
        assertEq(staking.shares(0, BOB), 762_500 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 6_100_000 ether);

        // simulate liquidCrowdloan switch redeem token from DOT to LDOT
        uint256 snapId = vm.snapshot();
        ldot.transfer(address(liquidCrowdloan), 4_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(4e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 4e18);
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 100_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(BOB, 0, 50_000 ether);
        staking.stakeTo(0, 100_000 ether, BOB);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 812_500 ether);
        assertEq(staking.shares(0, BOB), 812_500 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 6_500_000 ether);
        vm.revertTo(snapId);

        // simulate liquidCrowdloan switch redeem token from DOT to TDOT, can not stake LcDOT
        uint256 snapId2 = vm.snapshot();
        tdot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(tdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 100_000 ether);
        vm.expectRevert("unsupported convert");
        staking.stakeTo(0, 100_000 ether, BOB);
        vm.stopPrank();
        vm.revertTo(snapId2);
    }
}
