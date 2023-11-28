// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/ILSTConvert.sol";
import "../src/LCDOT2LDOTConvertor.sol";
import "./MockHoma.sol";
import "./MockToken.sol";
import "./MockLiquidCrowdloan.sol";

contract LCDOT2LDOTConvertorTest is Test {
    using stdStorage for StdStorage;

    LCDOT2LDOTConvertor public convertor;
    MockLiquidCrowdloan public liquidCrowdloan;
    MockHoma public homa;
    IERC20 public lcdot;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public tdot;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);

    function setUp() public {
        lcdot = IERC20(
            address(new MockToken("Acala LCDOT", "DOT", 1_000_000_000 ether))
        );
        dot = IERC20(
            address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether))
        );
        ldot = IERC20(
            address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether))
        );
        tdot = IERC20(
            address(new MockToken("Acala TDOT", "TDOT", 1_000_000_000 ether))
        );

        liquidCrowdloan = new MockLiquidCrowdloan(
            address(lcdot),
            address(dot),
            1e18
        );
        homa = new MockHoma(address(dot), address(ldot));
        convertor = new LCDOT2LDOTConvertor(
            address(liquidCrowdloan),
            address(homa),
            address(lcdot),
            address(dot),
            address(ldot)
        );
    }

    function test_inputToken() public {
        assertEq(convertor.inputToken(), address(lcdot));
    }

    function test_outputToken() public {
        assertEq(convertor.outputToken(), address(ldot));
    }

    function test_convert_revertZeroAmount() public {
        vm.expectRevert("LCDOT2LDOTConvertor: invalid input amount");
        convertor.convert(0);
    }

    function test_convert_liquidCrowdloanRedeemDOT() public {
        lcdot.transfer(ALICE, 100_000_000 ether);
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(lcdot.balanceOf(ALICE), 100_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);

        // simulate redeem 0 DOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore
            .target(address(liquidCrowdloan))
            .sig("redeemExchangeRate()")
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 20_000_000 ether);
        vm.expectRevert("LCDOT2LDOTConvertor: zero output");
        assertEq(convertor.convert(20_000_000 ether), 0);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 100_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        vm.revertTo(snapId);

        // simulate mint 0 LDOT by Homa
        uint256 snapId1 = vm.snapshot();
        uint256 slot1 = stdstore
            .target(address(homa))
            .sig("getExchangeRate()")
            .find();
        bytes32 loc1 = bytes32(slot1);
        vm.store(address(homa), loc1, zero);
        assertEq(homa.getExchangeRate(), 0);
        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 20_000_000 ether);
        vm.expectRevert(stdError.divisionError);
        assertEq(convertor.convert(20_000_000 ether), 0);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 100_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        vm.revertTo(snapId1);

        // convertion succeed
        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 20_000_000 ether);
        assertEq(convertor.convert(20_000_000 ether), 160_000_000 ether);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 80_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 160_000_000 ether);
    }

    function test_convert_liquidCrowdloanRedeemLDOT() public {
        lcdot.transfer(ALICE, 10_000_000 ether);
        ldot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        stdstore
            .target(address(liquidCrowdloan))
            .sig("getRedeemCurrency()")
            .checked_write(address(ldot));
        stdstore
            .target(address(liquidCrowdloan))
            .sig("redeemExchangeRate()")
            .checked_write(10e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 10e18);
        assertEq(lcdot.balanceOf(ALICE), 10_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);

        // simulate redeem zero LDOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore
            .target(address(liquidCrowdloan))
            .sig("redeemExchangeRate()")
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 2_000_000 ether);
        vm.expectRevert("LCDOT2LDOTConvertor: zero output");
        assertEq(convertor.convert(2_000_000 ether), 0);
        assertEq(lcdot.balanceOf(ALICE), 10_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        vm.revertTo(snapId);

        // convertion succeed
        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 2_000_000 ether);
        assertEq(convertor.convert(2_000_000 ether), 20_000_000 ether);
        assertEq(lcdot.balanceOf(ALICE), 8_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 20_000_000 ether);
    }

    function test_convert_revertUnsupported() public {
        lcdot.transfer(ALICE, 10_000_000 ether);
        tdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        stdstore
            .target(address(liquidCrowdloan))
            .sig("getRedeemCurrency()")
            .checked_write(address(tdot));
        stdstore
            .target(address(liquidCrowdloan))
            .sig("redeemExchangeRate()")
            .checked_write(1e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(tdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(lcdot.balanceOf(ALICE), 10_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 10_000_000 ether);
        vm.expectRevert("LCDOT2LDOTConvertor: unsupported convert");
        assertEq(convertor.convert(10_000_000 ether), 0);
        assertEq(lcdot.balanceOf(ALICE), 10_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
    }

    function test_convertTo_revertZeroAddress() public {
        vm.expectRevert("LCDOT2LDOTConvertor: zero address not allowed");
        convertor.convertTo(0, address(0));
    }

    function test_convertTo_revertZeroAmount() public {
        vm.expectRevert("LCDOT2LDOTConvertor: invalid input amount");
        convertor.convertTo(0, BOB);
    }

    function test_convertTo() public {
        lcdot.transfer(ALICE, 100_000_000 ether);
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(lcdot.balanceOf(ALICE), 100_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(lcdot.balanceOf(BOB), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(ldot.balanceOf(BOB), 0);

        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 20_000_000 ether);
        assertEq(convertor.convertTo(20_000_000 ether, BOB), 160_000_000 ether);
        assertEq(lcdot.balanceOf(ALICE), 80_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(lcdot.balanceOf(BOB), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(ldot.balanceOf(BOB), 160_000_000 ether);
    }
}
