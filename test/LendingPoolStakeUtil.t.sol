// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/LendingPoolStakeUtil.sol";
import "../src/UpgradeableStakingLSTV2.sol";
import "../src/WrappedTDOT.sol";
import "./MockHoma.sol";
import "./MockLiquidCrowdloan.sol";
import "./MockStableAsset.sol";
import "./MockLendingPool.sol";
import "./MockToken.sol";

contract LendingPoolStakeUtilTest is Test {
    using stdStorage for StdStorage;

    event Stake(address indexed account, uint256 poolId, uint256 amount);

    UpgradeableStakingLSTV2 public staking;
    MockHoma public homa;
    MockStableAsset public stableAsset;
    MockLiquidCrowdloan public liquidCrowdloan;
    MockLendingPool public lendingPool;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;
    IERC20 public dotLendingPoolShare;
    IERC20 public ldotLendingPoolShare;
    LendingPoolStakeUtil public util;
    WrappedTDOT public wtdot;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether)));
        lcdot = IERC20(address(new MockToken("Acala LcDOT", "LcDOT", 1_000_000_000 ether)));
        tdot = IERC20(address(new MockToken("Taiga DOT", "tDOT", 1_000_000_000 ether)));
        lcdot = IERC20(address(new MockToken("Acala LcDOT", "LcDOT", 1_000_000_000 ether)));
        dotLendingPoolShare = IERC20(address(new MockToken("LendingPool DOT", "lDOT", 0)));
        ldotLendingPoolShare = IERC20(address(new MockToken("LendingPool LDOT", "lLDOT", 0)));

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
        vm.startPrank(ADMIN);
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
        staking.addPool(dotLendingPoolShare);
        staking.addPool(ldotLendingPoolShare);
        vm.stopPrank();

        lendingPool = new MockLendingPool();
        lendingPool.setLToken(address(dot), address(dotLendingPoolShare));
        lendingPool.setLToken(address(ldot), address(ldotLendingPoolShare));

        util = new LendingPoolStakeUtil(
            address(staking),
            address(lendingPool)
        );
    }

    function test_depositAndStake_revertInvalidZeroAmount() public {
        vm.expectRevert("LendingPoolStakeUtil: zero amount is not allowed");
        util.depositAndStake(dot, 0, 0);
    }

    function test_depositAndStake_revertShareTokenNotMatched() public {
        vm.expectRevert(
            "LendingPoolStakeUtil: the pool share token of Euphrates is not matched the LendingPool lToken for asset"
        );
        util.depositAndStake(dot, 100 ether, 1);

        vm.expectRevert(
            "LendingPoolStakeUtil: the pool share token of Euphrates is not matched the LendingPool lToken for asset"
        );
        util.depositAndStake(ldot, 100 ether, 0);
    }

    function test_depositAndStake_works() public {
        dot.transfer(ALICE, 1_000_000 ether);
        ldot.transfer(ALICE, 1_000_000 ether);

        assertEq(dot.balanceOf(ALICE), 1_000_000 ether);
        assertEq(dotLendingPoolShare.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(address(util)), 0);
        assertEq(dotLendingPoolShare.balanceOf(address(util)), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(dotLendingPoolShare.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(lendingPool)), 0);
        assertEq(staking.shares(0, ALICE), 0);

        // ALICE deposit dot to LendingPool to get dotLendingPoolShare tUSD and stake to Euphrates pool by LendingPoolStakeUtil.depositAndStake
        vm.startPrank(ALICE);
        dot.approve(address(util), 1_000_000 ether);
        emit Stake(ALICE, 0, 1_000_000 ether);
        util.depositAndStake(dot, 1_000_000 ether, 0);
        vm.stopPrank();

        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(dotLendingPoolShare.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(address(util)), 0);
        assertEq(dotLendingPoolShare.balanceOf(address(util)), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(dotLendingPoolShare.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(dot.balanceOf(address(lendingPool)), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);

        assertEq(ldot.balanceOf(ALICE), 1_000_000 ether);
        assertEq(ldotLendingPoolShare.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(util)), 0);
        assertEq(ldotLendingPoolShare.balanceOf(address(util)), 0);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(ldotLendingPoolShare.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(lendingPool)), 0);
        assertEq(staking.shares(1, ALICE), 0);

        // ALICE deposit ldot to LendingPool to get ldotLendingPoolShare tUSD and stake to Euphrates pool by LendingPoolStakeUtil.depositAndStake
        vm.startPrank(ALICE);
        ldot.approve(address(util), 1_000_000 ether);
        emit Stake(ALICE, 1, 1_000_000 ether);
        util.depositAndStake(ldot, 1_000_000 ether, 1);
        vm.stopPrank();

        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldotLendingPoolShare.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(util)), 0);
        assertEq(ldotLendingPoolShare.balanceOf(address(util)), 0);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(ldotLendingPoolShare.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(lendingPool)), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
    }
}
