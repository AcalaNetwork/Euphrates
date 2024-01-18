// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/ILSTConvert.sol";
import "../src/LendingPoolDepositConvertor.sol";
import "./MockLendingPool.sol";
import "./MockToken.sol";

contract LendingPoolDepositConvertorTest is Test {
    using stdStorage for StdStorage;

    LendingPoolDepositConvertor public dotConvertor;
    LendingPoolDepositConvertor public ldotConvertor;
    MockLendingPool public lendingPool;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public dotLendingPoolShare;
    IERC20 public ldotLendingPoolShare;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether)));
        dotLendingPoolShare = IERC20(address(new MockToken("LendingPool DOT", "lDOT", 0)));
        ldotLendingPoolShare = IERC20(address(new MockToken("LendingPool LDOT", "lLDOT", 0)));

        lendingPool = new MockLendingPool();
        lendingPool.setLToken(address(dot), address(dotLendingPoolShare));
        lendingPool.setLToken(address(ldot), address(ldotLendingPoolShare));

        dotConvertor = new LendingPoolDepositConvertor(
            address(lendingPool),
            address(dot)
        );
        ldotConvertor = new LendingPoolDepositConvertor(
            address(lendingPool),
            address(ldot)
        );
    }

    function test_inputToken() public {
        assertEq(dotConvertor.inputToken(), address(dot));
        assertEq(ldotConvertor.inputToken(), address(ldot));
    }

    function test_outputToken() public {
        assertEq(dotConvertor.outputToken(), address(dotLendingPoolShare));
        assertEq(ldotConvertor.outputToken(), address(ldotLendingPoolShare));
    }

    function test_convert_revertZeroAmount() public {
        vm.expectRevert("LendingPoolDepositConvertor: invalid input amount");
        dotConvertor.convert(0);
    }

    function test_convert() public {
        dot.transfer(ALICE, 1_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 1_000_000 ether);
        assertEq(dotLendingPoolShare.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        dot.approve(address(dotConvertor), 1_000_000 ether);
        assertEq(dotConvertor.convert(1_000_000 ether), 1_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(dotLendingPoolShare.balanceOf(ALICE), 1_000_000 ether);
        vm.stopPrank();

        ldot.transfer(BOB, 1_000_000 ether);
        assertEq(ldot.balanceOf(BOB), 1_000_000 ether);
        assertEq(ldotLendingPoolShare.balanceOf(BOB), 0);

        vm.startPrank(BOB);
        ldot.approve(address(ldotConvertor), 1_000_000 ether);
        assertEq(ldotConvertor.convert(1_000_000 ether), 1_000_000 ether);
        assertEq(ldot.balanceOf(BOB), 0);
        assertEq(ldotLendingPoolShare.balanceOf(BOB), 1_000_000 ether);
    }

    function test_convertTo_revertZeroAddress() public {
        vm.expectRevert("LendingPoolDepositConvertor: zero address not allowed");
        dotConvertor.convertTo(0, address(0));
    }

    function test_convertTo_revertZeroAmount() public {
        vm.expectRevert("LendingPoolDepositConvertor: invalid input amount");
        dotConvertor.convertTo(0, BOB);
    }

    function test_convertTo() public {
        dot.transfer(ALICE, 1_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 1_000_000 ether);
        assertEq(dotLendingPoolShare.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(dotLendingPoolShare.balanceOf(BOB), 0);

        vm.startPrank(ALICE);
        dot.approve(address(dotConvertor), 1_000_000 ether);
        assertEq(dotConvertor.convertTo(1_000_000 ether, BOB), 1_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(dotLendingPoolShare.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(dotLendingPoolShare.balanceOf(BOB), 1_000_000 ether);
    }
}
