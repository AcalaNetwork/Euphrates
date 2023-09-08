// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./MockToken.sol";
import "../src/WrappedTDOT.sol";

contract WTDOTTest is Test {
    WrappedTDOT public wtdot;
    IERC20 public tdot;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);

    event Deposit(address indexed who, uint256 tdotAmount, uint256 wtdotAmount);
    event Withdraw(address indexed who, uint256 wtdotAmount, uint256 tdotAmount);

    function setUp() public {
        vm.prank(ALICE);
        tdot = IERC20(address(new MockToken("Acala tDOT", "tDOT", 1_000_000_000 ether)));
        wtdot = new WrappedTDOT(address(tdot));
    }

    function test_depositRate_noWTDOTIssued() public {
        assertEq(wtdot.depositRate(), 1e18);
        assertEq(wtdot.totalSupply(), 0);
        assertEq(tdot.balanceOf(address(wtdot)), 0);

        vm.prank(ALICE);
        tdot.transfer(address(wtdot), 100 ether);
        assertEq(wtdot.depositRate(), 1e18);
        assertEq(wtdot.totalSupply(), 0);
        assertEq(tdot.balanceOf(address(wtdot)), 100 ether);
    }

    function test_depositRate_noTDOTHold() public {
        vm.startPrank(ALICE);
        tdot.approve(address(wtdot), 100 ether);
        wtdot.deposit(100 ether);
        assertEq(wtdot.totalSupply(), 100 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 100 ether);
        assertEq(wtdot.depositRate(), 1e18);

        // mock no tdot hold
        MockToken(address(tdot)).forceTransfer(address(wtdot), ALICE, 100 ether);
        assertEq(wtdot.totalSupply(), 100 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 0);
        assertEq(wtdot.depositRate(), 1e18);
    }

    function test_withdrawRate_noWTDOTIssued() public {
        assertEq(wtdot.withdrawRate(), 0);
        assertEq(wtdot.totalSupply(), 0);
        assertEq(tdot.balanceOf(address(wtdot)), 0);

        vm.prank(ALICE);
        tdot.transfer(address(wtdot), 100 ether);
        assertEq(wtdot.withdrawRate(), 0);
        assertEq(wtdot.totalSupply(), 0);
        assertEq(tdot.balanceOf(address(wtdot)), 100 ether);
    }

    function test_withdrawRate_noTDOTHold() public {
        vm.startPrank(ALICE);
        tdot.approve(address(wtdot), 100 ether);
        wtdot.deposit(100 ether);
        assertEq(wtdot.totalSupply(), 100 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 100 ether);
        assertEq(wtdot.withdrawRate(), 1e18);

        // mock no tdot hold
        MockToken(address(tdot)).forceTransfer(address(wtdot), ALICE, 100 ether);
        assertEq(wtdot.totalSupply(), 100 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 0);
        assertEq(wtdot.withdrawRate(), 0);
    }

    function test_deposit_works() public {
        // ALICE deposit 100 TDOT to get 100 WTDOT
        vm.startPrank(ALICE);
        tdot.approve(address(wtdot), 100 ether);
        vm.expectEmit(true, false, false, true);
        emit Deposit(ALICE, 100 ether, 100 ether);
        assertEq(wtdot.deposit(100 ether), 100 ether);
        assertEq(wtdot.totalSupply(), 100 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 100 ether);
        assertEq(wtdot.balanceOf(ALICE), 100 ether);
        assertEq(tdot.balanceOf(ALICE), 999_999_900 ether);

        tdot.transfer(BOB, 200 ether);
        assertEq(wtdot.balanceOf(BOB), 0);
        assertEq(tdot.balanceOf(BOB), 200 ether);
        vm.stopPrank();

        // BOB deposit 200 TDOT to get 200 WTDOT
        vm.startPrank(BOB);
        tdot.approve(address(wtdot), 200 ether);
        vm.expectEmit(true, false, false, true);
        emit Deposit(BOB, 200 ether, 200 ether);
        assertEq(wtdot.deposit(200 ether), 200 ether);
        assertEq(wtdot.totalSupply(), 300 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 300 ether);
        assertEq(wtdot.balanceOf(BOB), 200 ether);
        assertEq(tdot.balanceOf(BOB), 0);
        vm.stopPrank();

        // mock hold tdot increase 100 TDOT
        vm.startPrank(ALICE);
        tdot.transfer(address(wtdot), 100 ether);
        assertEq(wtdot.totalSupply(), 300 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 400 ether);
        assertEq(wtdot.balanceOf(ALICE), 100 ether);
        assertEq(tdot.balanceOf(ALICE), 999_999_600 ether);

        // ALICE deposit 100 TDOT to get 75 WTDOT
        tdot.approve(address(wtdot), 100 ether);
        vm.expectEmit(true, false, false, true);
        emit Deposit(ALICE, 100 ether, 75 ether);
        assertEq(wtdot.deposit(100 ether), 75 ether);
        assertEq(wtdot.totalSupply(), 375 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 500 ether);
        assertEq(wtdot.balanceOf(ALICE), 175 ether);
        assertEq(tdot.balanceOf(ALICE), 999_999_500 ether);
    }

    function test_withdraw_revertNotEnough() public {
        vm.startPrank(ALICE);
        vm.expectRevert("WTDOT: WTDOT not enough");
        wtdot.withdraw(1_000 ether);
    }

    function test_withdraw_works() public {
        vm.startPrank(ALICE);
        tdot.approve(address(wtdot), 1000 ether);
        wtdot.deposit(1_000 ether);
        assertEq(wtdot.totalSupply(), 1_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 1_000 ether);
        assertEq(wtdot.balanceOf(ALICE), 1_000 ether);
        assertEq(tdot.balanceOf(ALICE), 999_999_000 ether);

        // ALICE withdraw 100 WTDOT to get 100 TDOT
        vm.expectEmit(true, false, false, true);
        emit Withdraw(ALICE, 100 ether, 100 ether);
        assertEq(wtdot.withdraw(100 ether), 100 ether);
        assertEq(wtdot.totalSupply(), 900 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 900 ether);
        assertEq(wtdot.balanceOf(ALICE), 900 ether);
        assertEq(tdot.balanceOf(ALICE), 999_999_100 ether);

        wtdot.transfer(BOB, 500 ether);
        assertEq(wtdot.balanceOf(BOB), 500 ether);
        assertEq(tdot.balanceOf(BOB), 0);
        vm.stopPrank();

        // BOB withdraw 100 WTDOT to get 100 TDOT
        vm.prank(BOB);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(BOB, 100 ether, 100 ether);
        assertEq(wtdot.withdraw(100 ether), 100 ether);
        assertEq(wtdot.totalSupply(), 800 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 800 ether);
        assertEq(wtdot.balanceOf(BOB), 400 ether);
        assertEq(tdot.balanceOf(BOB), 100 ether);

        // mock hold tdot increase 200 TDOT
        vm.prank(ALICE);
        tdot.transfer(address(wtdot), 200 ether);
        assertEq(wtdot.totalSupply(), 800 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 1_000 ether);

        // BOB withdraw 100 WTDOT to get TDOT
        vm.prank(BOB);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(BOB, 100 ether, 125 ether);
        assertEq(wtdot.withdraw(100 ether), 125 ether);
        assertEq(wtdot.totalSupply(), 700 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 875 ether);
        assertEq(wtdot.balanceOf(BOB), 300 ether);
        assertEq(tdot.balanceOf(BOB), 225 ether);

        // mock no tdot hold
        MockToken(address(tdot)).forceTransfer(address(wtdot), ALICE, 875 ether);
        assertEq(wtdot.totalSupply(), 700 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 0);

        vm.startPrank(BOB);
        vm.expectRevert("WTDOT: invalid TDOT amount");
        wtdot.withdraw(100 ether);
    }
}
