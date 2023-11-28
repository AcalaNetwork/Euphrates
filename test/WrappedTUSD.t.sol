// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./MockToken.sol";
import "../src/WrappedTUSD.sol";

contract WTUSDTest is Test {
    WrappedTUSD public wtusd;
    IERC20 public tusd;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);

    event Deposit(address indexed who, uint256 tusdAmount, uint256 wtusdAmount);
    event Withdraw(address indexed who, uint256 wtusdAmount, uint256 tusdAmount);

    function setUp() public {
        vm.prank(ALICE);
        tusd = IERC20(address(new MockToken("Taiga tUSD", "tUSD", 1_000_000_000 ether)));
        wtusd = new WrappedTUSD(address(tusd));
    }

    function test_depositRate_noWTUSDIssued() public {
        assertEq(wtusd.depositRate(), 1e18);
        assertEq(wtusd.totalSupply(), 0);
        assertEq(tusd.balanceOf(address(wtusd)), 0);

        vm.prank(ALICE);
        tusd.transfer(address(wtusd), 100 ether);
        assertEq(wtusd.depositRate(), 1e18);
        assertEq(wtusd.totalSupply(), 0);
        assertEq(tusd.balanceOf(address(wtusd)), 100 ether);
    }

    function test_depositRate_noTUSDHold() public {
        vm.startPrank(ALICE);
        tusd.approve(address(wtusd), 100 ether);
        wtusd.deposit(100 ether);
        assertEq(wtusd.totalSupply(), 100 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 100 ether);
        assertEq(wtusd.depositRate(), 1e18);

        // mock no tusd hold
        MockToken(address(tusd)).forceTransfer(address(wtusd), ALICE, 100 ether);
        assertEq(wtusd.totalSupply(), 100 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 0);
        assertEq(wtusd.depositRate(), 1e18);
    }

    function test_withdrawRate_noWTUSDIssued() public {
        assertEq(wtusd.withdrawRate(), 0);
        assertEq(wtusd.totalSupply(), 0);
        assertEq(tusd.balanceOf(address(wtusd)), 0);

        vm.prank(ALICE);
        tusd.transfer(address(wtusd), 100 ether);
        assertEq(wtusd.withdrawRate(), 0);
        assertEq(wtusd.totalSupply(), 0);
        assertEq(tusd.balanceOf(address(wtusd)), 100 ether);
    }

    function test_withdrawRate_noTUSDHold() public {
        vm.startPrank(ALICE);
        tusd.approve(address(wtusd), 100 ether);
        wtusd.deposit(100 ether);
        assertEq(wtusd.totalSupply(), 100 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 100 ether);
        assertEq(wtusd.withdrawRate(), 1e18);

        // mock no tusd hold
        MockToken(address(tusd)).forceTransfer(address(wtusd), ALICE, 100 ether);
        assertEq(wtusd.totalSupply(), 100 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 0);
        assertEq(wtusd.withdrawRate(), 0);
    }

    function test_deposit_works() public {
        // ALICE deposit 100 TUSD to get 100 WTUSD
        vm.startPrank(ALICE);
        tusd.approve(address(wtusd), 100 ether);
        vm.expectEmit(true, false, false, true);
        emit Deposit(ALICE, 100 ether, 100 ether);
        assertEq(wtusd.deposit(100 ether), 100 ether);
        assertEq(wtusd.totalSupply(), 100 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 100 ether);
        assertEq(wtusd.balanceOf(ALICE), 100 ether);
        assertEq(tusd.balanceOf(ALICE), 999_999_900 ether);

        tusd.transfer(BOB, 200 ether);
        assertEq(wtusd.balanceOf(BOB), 0);
        assertEq(tusd.balanceOf(BOB), 200 ether);
        vm.stopPrank();

        // BOB deposit 200 TUSD to get 200 WTUSD
        vm.startPrank(BOB);
        tusd.approve(address(wtusd), 200 ether);
        vm.expectEmit(true, false, false, true);
        emit Deposit(BOB, 200 ether, 200 ether);
        assertEq(wtusd.deposit(200 ether), 200 ether);
        assertEq(wtusd.totalSupply(), 300 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 300 ether);
        assertEq(wtusd.balanceOf(BOB), 200 ether);
        assertEq(tusd.balanceOf(BOB), 0);
        vm.stopPrank();

        // mock hold tusd increase 100 TUSD
        vm.startPrank(ALICE);
        tusd.transfer(address(wtusd), 100 ether);
        assertEq(wtusd.totalSupply(), 300 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 400 ether);
        assertEq(wtusd.balanceOf(ALICE), 100 ether);
        assertEq(tusd.balanceOf(ALICE), 999_999_600 ether);

        // ALICE deposit 100 TUSD to get 75 WTUSD
        tusd.approve(address(wtusd), 100 ether);
        vm.expectEmit(true, false, false, true);
        emit Deposit(ALICE, 100 ether, 75 ether);
        assertEq(wtusd.deposit(100 ether), 75 ether);
        assertEq(wtusd.totalSupply(), 375 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 500 ether);
        assertEq(wtusd.balanceOf(ALICE), 175 ether);
        assertEq(tusd.balanceOf(ALICE), 999_999_500 ether);
    }

    function test_withdraw_revertNotEnough() public {
        vm.startPrank(ALICE);
        vm.expectRevert("WTUSD: WTUSD not enough");
        wtusd.withdraw(1_000 ether);
    }

    function test_withdraw_works() public {
        vm.startPrank(ALICE);
        tusd.approve(address(wtusd), 1000 ether);
        wtusd.deposit(1_000 ether);
        assertEq(wtusd.totalSupply(), 1_000 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 1_000 ether);
        assertEq(wtusd.balanceOf(ALICE), 1_000 ether);
        assertEq(tusd.balanceOf(ALICE), 999_999_000 ether);

        // ALICE withdraw 100 WTUSD to get 100 TUSD
        vm.expectEmit(true, false, false, true);
        emit Withdraw(ALICE, 100 ether, 100 ether);
        assertEq(wtusd.withdraw(100 ether), 100 ether);
        assertEq(wtusd.totalSupply(), 900 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 900 ether);
        assertEq(wtusd.balanceOf(ALICE), 900 ether);
        assertEq(tusd.balanceOf(ALICE), 999_999_100 ether);

        wtusd.transfer(BOB, 500 ether);
        assertEq(wtusd.balanceOf(BOB), 500 ether);
        assertEq(tusd.balanceOf(BOB), 0);
        vm.stopPrank();

        // BOB withdraw 100 WTUSD to get 100 TUSD
        vm.prank(BOB);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(BOB, 100 ether, 100 ether);
        assertEq(wtusd.withdraw(100 ether), 100 ether);
        assertEq(wtusd.totalSupply(), 800 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 800 ether);
        assertEq(wtusd.balanceOf(BOB), 400 ether);
        assertEq(tusd.balanceOf(BOB), 100 ether);

        // mock hold tusd increase 200 TUSD
        vm.prank(ALICE);
        tusd.transfer(address(wtusd), 200 ether);
        assertEq(wtusd.totalSupply(), 800 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 1_000 ether);

        // BOB withdraw 100 WTUSD to get TUSD
        vm.prank(BOB);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(BOB, 100 ether, 125 ether);
        assertEq(wtusd.withdraw(100 ether), 125 ether);
        assertEq(wtusd.totalSupply(), 700 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 875 ether);
        assertEq(wtusd.balanceOf(BOB), 300 ether);
        assertEq(tusd.balanceOf(BOB), 225 ether);

        // mock no tusd hold
        MockToken(address(tusd)).forceTransfer(address(wtusd), ALICE, 875 ether);
        assertEq(wtusd.totalSupply(), 700 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 0);

        vm.startPrank(BOB);
        vm.expectRevert("WTUSD: invalid TUSD amount");
        wtusd.withdraw(100 ether);
    }
}
