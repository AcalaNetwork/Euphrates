// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/ILSTConvert.sol";
import "../src/DOT2LDOTConvertor.sol";
import "./MockHoma.sol";
import "./MockToken.sol";

contract DOT2LDOTConvertorTest is Test {
    using stdStorage for StdStorage;

    DOT2LDOTConvertor public convertor;
    MockHoma public homa;
    IERC20 public dot;
    IERC20 public ldot;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);

    function setUp() public {
        dot = IERC20(
            address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether))
        );
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 0 ether)));

        homa = new MockHoma(address(dot), address(ldot));
        convertor = new DOT2LDOTConvertor(
            address(homa),
            address(dot),
            address(ldot)
        );
    }

    function test_inputToken() public {
        assertEq(convertor.inputToken(), address(dot));
    }

    function test_outputToken() public {
        assertEq(convertor.outputToken(), address(ldot));
    }

    function test_convert_revertZeroAmount() public {
        vm.expectRevert("DOT2LDOTConvertor: invalid input amount");
        convertor.convert(0);
    }

    function test_convert() public {
        dot.transfer(ALICE, 20_000_000 ether);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(dot.balanceOf(ALICE), 20_000_000 ether);
        assertEq(ldot.balanceOf(ALICE), 0 ether);

        vm.startPrank(ALICE);
        dot.approve(address(convertor), 20_000_000 ether);
        assertEq(convertor.convert(20_000_000 ether), 160_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0 ether);
        assertEq(ldot.balanceOf(ALICE), 160_000_000 ether);
    }

    function test_convertTo_revertZeroAddress() public {
        vm.expectRevert("DOT2LDOTConvertor: zero address not allowed");
        convertor.convertTo(0, address(0));
    }

    function test_convertTo_revertZeroAmount() public {
        vm.expectRevert("DOT2LDOTConvertor: invalid input amount");
        convertor.convertTo(0, BOB);
    }

    function test_convertTo() public {
        dot.transfer(ALICE, 20_000_000 ether);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(dot.balanceOf(ALICE), 20_000_000 ether);
        assertEq(ldot.balanceOf(ALICE), 0 ether);
        assertEq(dot.balanceOf(BOB), 0 ether);
        assertEq(ldot.balanceOf(BOB), 0 ether);

        vm.startPrank(ALICE);
        dot.approve(address(convertor), 20_000_000 ether);
        assertEq(convertor.convertTo(20_000_000 ether, BOB), 160_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0 ether);
        assertEq(ldot.balanceOf(ALICE), 0 ether);
        assertEq(dot.balanceOf(BOB), 0 ether);
        assertEq(ldot.balanceOf(BOB), 160_000_000 ether);
    }
}
