// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/ILSTConvert.sol";
import "../src/DOT2WTDOTConvertor.sol";
import "../src/WrappedTDOT.sol";
import "./MockHoma.sol";
import "./MockToken.sol";
import "./MockStableAsset.sol";

contract DOT2WTDOTConvertorTest is Test {
    using stdStorage for StdStorage;

    DOT2WTDOTConvertor public convertor;
    MockHoma public homa;
    MockStableAsset public stableAsset;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public tdot;
    WrappedTDOT public wtdot;
    address public ALICE = address(0x1111);
    address public BOB = address(0x2222);

    function setUp() public {
        dot = IERC20(
            address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether))
        );
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 0 ether)));
        tdot = IERC20(address(new MockToken("Acala tDOT", "tDOT", 0 ether)));
        wtdot = new WrappedTDOT(address(tdot));

        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAsset(
            address(dot),
            address(ldot),
            address(tdot),
            address(homa)
        );
        convertor = new DOT2WTDOTConvertor(
            address(stableAsset),
            address(homa),
            address(dot),
            address(ldot),
            address(tdot),
            address(wtdot)
        );
    }

    function test_inputToken() public {
        assertEq(convertor.inputToken(), address(dot));
    }

    function test_outputToken() public {
        assertEq(convertor.outputToken(), address(wtdot));
    }

    function test_convert_revertZeroAmount() public {
        vm.expectRevert("DOT2WTDOTConvertor: invalid input amount");
        convertor.convert(0);
    }

    function test_convert_halfDOTMintLDOT() public {
        uint256 amount = convertor.HOMA_MINT_THRESHOLD() * 2;
        dot.transfer(ALICE, amount);
        assertEq(dot.balanceOf(ALICE), amount);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        dot.approve(address(convertor), amount);
        assertEq(convertor.convert(amount), 90_000_000_000);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 90_000_000_000);
    }

    function test_convert_withoutHomaMint() public {
        uint256 amount = convertor.HOMA_MINT_THRESHOLD() * 2 - 1;
        dot.transfer(ALICE, amount);
        assertEq(dot.balanceOf(ALICE), amount);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);

        vm.startPrank(ALICE);
        dot.approve(address(convertor), amount);
        assertEq(convertor.convert(amount), amount);
        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), amount);
    }

    function test_convertTo_revertZeroAddress() public {
        vm.expectRevert("DOT2WTDOTConvertor: zero address not allowed");
        convertor.convertTo(0, address(0));
    }

    function test_convertTo_revertZeroAmount() public {
        vm.expectRevert("DOT2WTDOTConvertor: invalid input amount");
        convertor.convertTo(0, BOB);
    }

    function test_convertTo_halfDOTMintLDOT() public {
        uint256 amount = convertor.HOMA_MINT_THRESHOLD() * 2;
        dot.transfer(ALICE, amount);
        assertEq(dot.balanceOf(ALICE), amount);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(tdot.balanceOf(BOB), 0);
        assertEq(wtdot.balanceOf(BOB), 0);

        vm.startPrank(ALICE);
        dot.approve(address(convertor), amount);
        assertEq(convertor.convertTo(amount, BOB), 90_000_000_000);
        assertEq(dot.balanceOf(ALICE), 0 ether);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(tdot.balanceOf(BOB), 0);
        assertEq(wtdot.balanceOf(BOB), 90_000_000_000);
    }

    function test_convertTo_withoutHomaMint() public {
        uint256 amount = convertor.HOMA_MINT_THRESHOLD() * 2 - 1;
        dot.transfer(ALICE, amount);
        assertEq(dot.balanceOf(ALICE), amount);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(tdot.balanceOf(BOB), 0);
        assertEq(wtdot.balanceOf(BOB), 0);

        vm.startPrank(ALICE);
        dot.approve(address(convertor), amount);
        assertEq(convertor.convertTo(amount, BOB), amount);
        assertEq(dot.balanceOf(ALICE), 0 ether);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        assertEq(dot.balanceOf(BOB), 0);
        assertEq(tdot.balanceOf(BOB), 0);
        assertEq(wtdot.balanceOf(BOB), amount);
    }
}
