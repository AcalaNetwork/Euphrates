// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/DEXStakeUtil.sol";
import "../src/UpgradeableStakingLSTV2.sol";
import "./MockHoma.sol";
import "./MockLiquidCrowdloan.sol";
import "./MockStableAsset.sol";
import "./MockToken.sol";
import "./MockDEX.sol";

contract DEXStakeUtilTest is Test {
    using stdStorage for StdStorage;

    UpgradeableStakingLSTV2 public staking;
    MockDEX public dex;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public usdt;
    IERC20 public dotUsdtLp;
    DEXStakeUtil public util;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);
    address public BOB = address(0x3333);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala liquid staking DOT", "LDOT", 1_000_000_000 ether)));
        usdt = IERC20(address(new MockToken("Asset Hub USDT", "USDT", 1_000_000_000 ether)));
        dotUsdtLp = IERC20(address(new MockToken("Acala DEX DOT-USDT LP token", "DOTUSDT", 0 ether)));

        staking = new UpgradeableStakingLSTV2();
        staking.initialize(
            address(0x9999),
            address(0x9999),
            address(0x9999),
            address(0x9999),
            address(0x9999),
            address(0x9999),
            address(0x9999),
            address(0x9999)
        );
        dex = new MockDEX(address(dot), address(usdt), address(dotUsdtLp));
        util = new DEXStakeUtil(address(staking), address(dex));
    }

    function test_addLiquidityAndStake_revertInvalidTradingPair() public {
        vm.expectRevert("DEXStakeUtil: invalid trading pair");
        util.addLiquidityAndStake(dot, 0, ldot, 0, 0, 0);
    }

    function test_addLiquidityAndStake_revertInvalidPool() public {
        vm.expectRevert("DEXStakeUtil: invalid pool");
        util.addLiquidityAndStake(dot, 0, usdt, 0, 0, 0);
    }

    function test_addLiquidityAndStake_revertInvalidAmount() public {
        staking.addPool(dotUsdtLp);
        vm.expectRevert("DEXStakeUtil: invalid amount");
        util.addLiquidityAndStake(dot, 0, usdt, 0, 0, 0);
    }

    function test_addLiquidityAndStake_revertAddLiquidityFailed() public {
        staking.addPool(dotUsdtLp);
        dot.approve(address(util), 100 ether);
        usdt.approve(address(util), 1000 ether);
        vm.expectRevert("MockDEX: add liquidity failed");
        util.addLiquidityAndStake(dot, 100 ether, usdt, 1000 ether, 101 ether, 0);
    }

    function test_addLiquidityAndStake_works() public {
        staking.addPool(dotUsdtLp);
        dot.transfer(ALICE, 100 ether);
        usdt.transfer(ALICE, 1000 ether);

        vm.startPrank(ALICE);
        dot.approve(address(util), 100 ether);
        usdt.approve(address(util), 1000 ether);

        assertEq(dot.balanceOf(ALICE), 100 ether);
        assertEq(usdt.balanceOf(ALICE), 1000 ether);
        assertEq(dot.balanceOf(address(util)), 0);
        assertEq(usdt.balanceOf(address(util)), 0);
        assertEq(dotUsdtLp.balanceOf(address(util)), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(dotUsdtLp.balanceOf(address(staking)), 0);

        util.addLiquidityAndStake(dot, 100 ether, usdt, 1000 ether, 90 ether, 0);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(usdt.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(address(util)), 0);
        assertEq(usdt.balanceOf(address(util)), 0);
        assertEq(dotUsdtLp.balanceOf(address(util)), 0);
        assertEq(staking.shares(0, ALICE), 100 ether);
        assertEq(dotUsdtLp.balanceOf(address(staking)), 100 ether);
        vm.stopPrank();

        // refund remain assets
        dot.transfer(BOB, 100 ether);
        usdt.transfer(BOB, 100 ether);

        vm.startPrank(BOB);
        dot.approve(address(util), 100 ether);
        usdt.approve(address(util), 100 ether);
        assertEq(dot.balanceOf(BOB), 100 ether);
        assertEq(usdt.balanceOf(BOB), 100 ether);
        assertEq(staking.shares(0, BOB), 0);
        assertEq(dotUsdtLp.balanceOf(address(staking)), 100 ether);

        util.addLiquidityAndStake(dot, 100 ether, usdt, 100 ether, 0, 0);
        assertEq(dot.balanceOf(BOB), 90 ether);
        assertEq(usdt.balanceOf(BOB), 0 ether);
        assertEq(staking.shares(0, BOB), 10 ether);
        assertEq(dotUsdtLp.balanceOf(address(staking)), 110 ether);
    }

    function test_swapAndAddLiquidityAndStake_revertInvalidTradingPair() public {
        vm.expectRevert("DEXStakeUtil: invalid trading pair");
        util.swapAndAddLiquidityAndStake(dot, 0, ldot, 0, new address[](0), 0, 0, 0);
    }

    function test_swapAndAddLiquidityAndStake_revertInvalidPool() public {
        vm.expectRevert("DEXStakeUtil: invalid pool");
        util.swapAndAddLiquidityAndStake(dot, 0, usdt, 0, new address[](0), 0, 0, 0);
    }

    function test_swapAndAddLiquidityAndStake_revertInvalidSwapPathLength() public {
        staking.addPool(dotUsdtLp);
        vm.expectRevert("DEXStakeUtil: invalid swap path length");
        util.swapAndAddLiquidityAndStake(dot, 0, usdt, 0, new address[](0), 0, 0, 0);
    }

    function test_swapAndAddLiquidityAndStake_revertInvalidSwapPath() public {
        staking.addPool(dotUsdtLp);

        address[] memory path0 = new address[](2);
        address[] memory path1 = new address[](2);
        path1[0] = address(dot);
        path1[1] = address(ldot);
        address[] memory path2 = new address[](2);
        path2[0] = address(usdt);
        path2[1] = address(usdt);

        vm.expectRevert("DEXStakeUtil: invalid swap path");
        util.swapAndAddLiquidityAndStake(dot, 0, usdt, 0, path0, 0, 0, 0);

        vm.expectRevert("DEXStakeUtil: invalid swap path");
        util.swapAndAddLiquidityAndStake(dot, 0, usdt, 0, path1, 0, 0, 0);

        vm.expectRevert("DEXStakeUtil: invalid swap path");
        util.swapAndAddLiquidityAndStake(dot, 0, usdt, 0, path2, 0, 0, 0);
    }

    function test_swapAndAddLiquidityAndStake_revertInvalidSwapAmount() public {
        staking.addPool(dotUsdtLp);
        dot.transfer(ALICE, 100 ether);
        usdt.transfer(ALICE, 1000 ether);

        address[] memory path = new address[](2);
        path[0] = address(dot);
        path[1] = address(usdt);

        vm.startPrank(ALICE);
        dot.approve(address(util), 100 ether);
        usdt.approve(address(util), 1000 ether);
        vm.expectRevert("DEXStakeUtil: invalid swap amount");
        util.swapAndAddLiquidityAndStake(dot, 100 ether, usdt, 1000 ether, path, 0, 0, 0);

        vm.expectRevert("DEXStakeUtil: invalid swap amount");
        util.swapAndAddLiquidityAndStake(dot, 100 ether, usdt, 1000 ether, path, 101 ether, 0, 0);
    }

    function test_swapAndAddLiquidityAndStake_revertInvalidSwapFailed() public {
        staking.addPool(dotUsdtLp);
        dot.transfer(ALICE, 100 ether);
        usdt.transfer(ALICE, 1000 ether);

        address[] memory path = new address[](2);
        path[0] = address(dot);
        path[1] = address(usdt);

        vm.startPrank(ALICE);
        dot.approve(address(util), 100 ether);
        usdt.approve(address(util), 1000 ether);
        vm.expectRevert("MockDEX: swap failed");
        util.swapAndAddLiquidityAndStake(dot, 100 ether, usdt, 1000 ether, path, 50 ether, 0, 0);
    }

    function test_swapAndAddLiquidityAndStake_works() public {
        staking.addPool(dotUsdtLp);
        dot.transfer(ALICE, 350 ether);
        dex.addLiquidity(address(dot), address(usdt), 100 ether, 1000 ether, 0);

        address[] memory path0 = new address[](2);
        path0[0] = address(dot);
        path0[1] = address(usdt);

        vm.startPrank(ALICE);
        dot.approve(address(util), 350 ether);
        assertEq(dot.balanceOf(ALICE), 350 ether);
        assertEq(usdt.balanceOf(ALICE), 0 ether);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(dotUsdtLp.balanceOf(address(staking)), 0);

        util.swapAndAddLiquidityAndStake(dot, 300 ether, usdt, 0, path0, 100 ether, 0, 0);
        assertEq(dot.balanceOf(ALICE), 50 ether);
        assertEq(usdt.balanceOf(ALICE), 0 ether);
        assertEq(staking.shares(0, ALICE), 100 ether);
        assertEq(dotUsdtLp.balanceOf(address(staking)), 100 ether);
        vm.stopPrank();
    }
}
