// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/ILSTConvert.sol";
import "../src/LCDOT2WTDOTConvertor.sol";
import "../src/WrappedTDOT.sol";
import "./MockHoma.sol";
import "./MockToken.sol";
import "./MockStableAsset.sol";
import "./MockLiquidCrowdloan.sol";

contract LCDOT2WTDOTConvertorTest is Test {
    using stdStorage for StdStorage;

    LCDOT2WTDOTConvertor public convertor;
    MockLiquidCrowdloan public liquidCrowdloan;
    MockHoma public homa;
    MockStableAsset public stableAsset;
    IERC20 public lcdot;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public tdot;
    WrappedTDOT public wtdot;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);

    function setUp() public {
        lcdot = IERC20(
            address(new MockToken("Acala LCDOT", "DOT", 1_000_000_000 ether))
        );
        ldot = IERC20(
            address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether))
        );
        tdot = IERC20(
            address(new MockToken("Acala TDOT", "TDOT", 1_000_000_000 ether))
        );
        dot = IERC20(
            address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether))
        );
        wtdot = new WrappedTDOT(address(tdot));

        liquidCrowdloan = new MockLiquidCrowdloan(
            address(lcdot),
            address(dot),
            1e18
        );
        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAsset(
            address(dot),
            address(ldot),
            address(tdot),
            address(homa)
        );
        convertor = new LCDOT2WTDOTConvertor(
            address(liquidCrowdloan),
            address(stableAsset),
            address(homa),
            address(lcdot),
            address(dot),
            address(ldot),
            address(tdot),
            address(wtdot)
        );
    }

    function test_inputToken() public {
        assertEq(convertor.inputToken(), address(lcdot));
    }

    function test_outputToken() public {
        assertEq(convertor.outputToken(), address(wtdot));
    }

    function test_convert_revertZeroAmount() public {
        vm.expectRevert("LCDOT2WTDOTConvertor: invalid input amount");
        convertor.convert(0);
    }

    function test_convert_liquidCrowdloanRedeemDOT() public {
        uint256 amount = convertor.HOMA_MINT_THRESHOLD() * 2;
        lcdot.transfer(ALICE, amount);
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(lcdot.balanceOf(ALICE), amount);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);

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
        lcdot.approve(address(convertor), amount);
        vm.expectRevert("MockStableAsset: invalid amounts");
        assertEq(convertor.convert(amount), 0);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), amount);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        vm.revertTo(snapId);

        // simulate half redeemed DOT mint LDOT 0 by Homa
        uint256 snapId1 = vm.snapshot();
        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), amount);
        assertEq(convertor.convert(amount), 90_000_000_000);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 90_000_000_000);
        vm.revertTo(snapId1);

        // simulate without redeemed DOT to do homa mint
        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), amount - 1);
        assertEq(convertor.convert(amount - 1), amount - 1);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 1);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), amount - 1);
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
            .checked_write(8e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 8e18);
        assertEq(lcdot.balanceOf(ALICE), 10_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 10_000_000 ether);
        assertEq(convertor.convert(10_000_000 ether), 8_000_000 ether);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 8_000_000 ether);
    }

    function test_convert_liquidCrowdloanRedeemTDOT() public {
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
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);

        // simulate redeem 0 TDOT by liquidCrowdloan
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
        lcdot.approve(address(convertor), 10_000_000 ether);
        vm.expectRevert("WTDOT: invalid WTDOT amount");
        assertEq(convertor.convert(10_000_000 ether), 0);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 10_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        vm.revertTo(snapId);

        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 10_000_000 ether);
        assertEq(convertor.convert(10_000_000 ether), 10_000_000 ether);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 10_000_000 ether);
    }

    function test_convert_revertUnsupported() public {
        lcdot.transfer(ALICE, 10_000_000 ether);
        lcdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        stdstore
            .target(address(liquidCrowdloan))
            .sig("getRedeemCurrency()")
            .checked_write(address(lcdot));
        stdstore
            .target(address(liquidCrowdloan))
            .sig("redeemExchangeRate()")
            .checked_write(1e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(lcdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(lcdot.balanceOf(ALICE), 10_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), 10_000_000 ether);
        vm.expectRevert("LCDOT2WTDOTConvertor: unsupported convert");
        assertEq(convertor.convert(10_000_000 ether), 0);
        vm.stopPrank();
        assertEq(lcdot.balanceOf(ALICE), 10_000_000 ether);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
    }

    function test_convertTo_revertZeroAddress() public {
        vm.expectRevert("LCDOT2WTDOTConvertor: zero address not allowed");
        convertor.convertTo(0, address(0));
    }

    function test_convertTo_revertZeroAmount() public {
        vm.expectRevert("LCDOT2WTDOTConvertor: invalid input amount");
        convertor.convertTo(0, BOB);
    }

    function test_convertTo() public {
        uint256 amount = convertor.HOMA_MINT_THRESHOLD() * 2;
        lcdot.transfer(ALICE, amount);
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(lcdot.balanceOf(ALICE), amount);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        assertEq(lcdot.balanceOf(BOB), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(ldot.balanceOf(BOB), 0);
        assertEq(tdot.balanceOf(BOB), 0);
        assertEq(wtdot.balanceOf(BOB), 0);

        vm.startPrank(ALICE);
        lcdot.approve(address(convertor), amount);
        assertEq(convertor.convertTo(amount, BOB), 90_000_000_000);
        assertEq(lcdot.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(lcdot.balanceOf(BOB), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(ldot.balanceOf(BOB), 0);
        assertEq(lcdot.balanceOf(BOB), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(ldot.balanceOf(BOB), 0);
        assertEq(tdot.balanceOf(BOB), 0);
        assertEq(wtdot.balanceOf(BOB), 90_000_000_000);
    }
}
