// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/UpgradeableStakingLSTV2.sol";
import "../src/WrappedTDOT.sol";
import "../src/DOT2LDOTConvertor.sol";
import "../src/DOT2WTDOTConvertor.sol";
import "../src/LCDOT2LDOTConvertor.sol";
import "../src/LCDOT2WTDOTConvertor.sol";
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
    DOT2LDOTConvertor dot2ldotConvertor;
    DOT2WTDOTConvertor dot2wtdotConvertor;
    LCDOT2LDOTConvertor lcdot2ldotConvertor;
    LCDOT2WTDOTConvertor lcdot2wtdotConvertor;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;
    IERC20 public aca;
    WrappedTDOT public wtdot;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);
    address public BOB = address(0x3333);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        lcdot = IERC20(address(new MockToken("Acala LcDOT", "LcDOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether)));
        tdot = IERC20(address(new MockToken("Acala tDOT", "tDOT", 1_000_000_000 ether)));
        aca = IERC20(address(new MockToken("Acala", "ACA", 1_000_000_000 ether)));
        wtdot = new WrappedTDOT(address(tdot));

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
        dot2ldotConvertor = new DOT2LDOTConvertor(
            address(homa),
            address(dot),
            address(ldot)
        );
        dot2wtdotConvertor = new DOT2WTDOTConvertor(
            address(stableAsset),
            address(homa),
            address(dot),
            address(ldot),
            address(tdot),
            address(wtdot)
        );
        lcdot2ldotConvertor = new LCDOT2LDOTConvertor(
            address(liquidCrowdloan),
            address(homa),
            address(lcdot),
            address(dot),
            address(ldot)
        );
        lcdot2wtdotConvertor = new LCDOT2WTDOTConvertor(
            address(liquidCrowdloan),
            address(stableAsset),
            address(homa),
            address(lcdot),
            address(dot),
            address(ldot),
            address(tdot),
            address(wtdot)
        );

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

    function test_convertLSTPool_revertDeprecatedFunction() public {
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        vm.expectRevert("deprecated");
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
    }

    function test_convertLSTPool_revertNotOwner() public {
        assertEq(staking.owner(), ADMIN);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.convertLSTPool(0, lcdot2ldotConvertor);
    }

    function test_convertLSTPool_revertEmptyPool() public {
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        vm.expectRevert("pool is empty");
        staking.convertLSTPool(0, lcdot2ldotConvertor);
    }

    function test_convertLSTPool_revertDismatchShareType() public {
        vm.startPrank(ADMIN);
        staking.addPool(dot);
        staking.addPool(lcdot);
        vm.stopPrank();

        dot.approve(address(staking), 1_000_000 ether);
        lcdot.approve(address(staking), 1_000_000 ether);
        staking.stake(0, 100_000 ether);
        staking.stake(1, 100_000 ether);

        vm.startPrank(ADMIN);
        vm.expectRevert("convertor is not matched");
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        vm.expectRevert("convertor is not matched");
        staking.convertLSTPool(0, lcdot2wtdotConvertor);
        vm.expectRevert("convertor is not matched");
        staking.convertLSTPool(1, dot2ldotConvertor);
        vm.expectRevert("convertor is not matched");
        staking.convertLSTPool(1, dot2wtdotConvertor);
        vm.stopPrank();
    }

    function test_convertLSTPool_LCDOT2LDOT() public {
        lcdot.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(lcdot);
        assertEq(address(staking.shareTypes(0)), address(lcdot));

        // stake share LCDOT to pool
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 1_000_000 ether);
        staking.stake(0, 1_000_000 ether);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.stopPrank();

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);

        // simulate redeem 0 DOT by LiquidCrowdloan
        uint256 snapId = vm.snapshot();
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        vm.prank(ADMIN);
        vm.expectRevert("LCDOT2LDOTConvertor: zero output");
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        vm.revertTo(snapId);

        // simulate redeem DOT by LiquidCrowdloan but mint 0 LDOT by Homa
        uint256 snapId1 = vm.snapshot();
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        uint256 slot1 = stdstore.target(address(homa)).sig("getExchangeRate()").find();
        bytes32 loc1 = bytes32(slot1);
        bytes32 zero1 = bytes32(abi.encode(0));
        vm.store(address(homa), loc1, zero1);
        assertEq(homa.getExchangeRate(), 0);
        vm.prank(ADMIN);
        vm.expectRevert(stdError.divisionError);
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        vm.revertTo(snapId1);

        // simulate convert LCDOT pool to LDOT pool, and liquidCrowdloan redeem token is DOT
        uint256 snapId2 = vm.snapshot();
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, ldot, 1_000_000 ether, 8_000_000 ether);
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 8e18);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2ldotConvertor));

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        vm.revertTo(snapId2);

        // convert LCDOT pool to LDOT pool, and liquidCrowdloan redeem token is LDOT
        uint256 snapId3 = vm.snapshot();
        ldot.transfer(address(liquidCrowdloan), 10_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(10e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 10e18);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, ldot, 1_000_000 ether, 10_000_000 ether);
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 10_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 10e18);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2ldotConvertor));
        vm.revertTo(snapId3);

        // simulate convert LCDOT pool to LDOT pool, and liquidCrowdloan redeem token is TDOT
        uint256 snapId4 = vm.snapshot();
        tdot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(tdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.prank(ADMIN);
        vm.expectRevert("LCDOT2LDOTConvertor: unsupported convert");
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        vm.revertTo(snapId4);
    }

    function test_convertLSTPool_DOT2LDOT() public {
        dot.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(dot);
        assertEq(address(staking.shareTypes(0)), address(dot));

        // stake share DOT to pool
        vm.startPrank(ALICE);
        dot.approve(address(staking), 1_000_000 ether);
        staking.stake(0, 1_000_000 ether);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.stopPrank();

        assertEq(homa.getExchangeRate(), 1e18 / 8);

        // simulate mint 0 LDOT by Homa
        uint256 snapId1 = vm.snapshot();
        uint256 slot1 = stdstore.target(address(homa)).sig("getExchangeRate()").find();
        bytes32 loc1 = bytes32(slot1);
        bytes32 zero1 = bytes32(abi.encode(0));
        vm.store(address(homa), loc1, zero1);
        assertEq(homa.getExchangeRate(), 0);
        vm.prank(ADMIN);
        vm.expectRevert(stdError.divisionError);
        staking.convertLSTPool(0, dot2ldotConvertor);
        vm.revertTo(snapId1);

        // simulate convert DOT pool to LDOT pool, and liquidCrowdloan redeem token is DOT
        uint256 snapId2 = vm.snapshot();
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, dot, ldot, 1_000_000 ether, 8_000_000 ether);
        staking.convertLSTPool(0, dot2ldotConvertor);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 8e18);
        assertEq(address(staking.poolConvertors(0)), address(dot2ldotConvertor));

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSTPool(0, dot2ldotConvertor);
        vm.revertTo(snapId2);
    }

    function test_convertLSTPool_LCDOT2WTDOT() public {
        lcdot.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(lcdot);
        assertEq(address(staking.shareTypes(0)), address(lcdot));

        // stake share LCDOT to pool
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 1_000_000 ether);
        staking.stake(0, 1_000_000 ether);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.stopPrank();

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);

        // simulate convert LCDOT pool to WTDOT pool, and liquidCrowdloan redeem token is DOT
        uint256 snapId = vm.snapshot();
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, IERC20(address(wtdot)), 1_000_000 ether, 900_000 ether);
        staking.convertLSTPool(0, lcdot2wtdotConvertor);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 900_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 9e17);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2wtdotConvertor));
        vm.revertTo(snapId);

        // simulate convert LCDOT pool to WTDOT pool, and liquidCrowdloan redeem token is LDOT
        uint256 snapId1 = vm.snapshot();
        ldot.transfer(address(liquidCrowdloan), 10_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(10e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 10e18);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, IERC20(address(wtdot)), 1_000_000 ether, 1_000_000 ether);
        staking.convertLSTPool(0, lcdot2wtdotConvertor);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 1e18);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2wtdotConvertor));
        vm.revertTo(snapId1);

        // simulate convert LCDOT pool to WTDOT pool, and liquidCrowdloan redeem token is TDOT
        uint256 snapId2 = vm.snapshot();
        tdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(101e16);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(tdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 101e16);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, IERC20(address(wtdot)), 1_000_000 ether, 1_010_000 ether);
        staking.convertLSTPool(0, lcdot2wtdotConvertor);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 1_010_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 101e16);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2wtdotConvertor));
        vm.revertTo(snapId2);
    }

    function test_convertLSTPool_DOT2WTDOT() public {
        dot.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(dot);
        assertEq(address(staking.shareTypes(0)), address(dot));

        // stake share DOT to pool
        vm.startPrank(ALICE);
        dot.approve(address(staking), 1_000_000 ether);
        staking.stake(0, 1_000_000 ether);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(address(staking.poolConvertors(0)), address(0));
        vm.stopPrank();

        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, dot, IERC20(address(wtdot)), 1_000_000 ether, 900_000 ether);
        staking.convertLSTPool(0, dot2wtdotConvertor);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 900_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 9e17);
        assertEq(address(staking.poolConvertors(0)), address(dot2wtdotConvertor));

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSTPool(0, dot2wtdotConvertor);
    }

    function test_resetPoolConvertor_revertNotOwner() public {
        assertEq(staking.owner(), ADMIN);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.resetPoolConvertor(0, lcdot2ldotConvertor);
    }

    function test_resetPoolConvertor_revertInvalidPool() public {
        vm.prank(ADMIN);
        vm.expectRevert("invalid pool");
        staking.resetPoolConvertor(0, lcdot2ldotConvertor);
    }

    function test_resetPoolConvertor_revertNotConvertedPool() public {
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        vm.expectRevert("pool must be already converted");
        staking.resetPoolConvertor(0, lcdot2ldotConvertor);
    }

    function test_resetPoolConvertor_revertConvertorNotMatch() public {
        lcdot.transfer(ALICE, 1_000_000 ether);

        vm.prank(ADMIN);
        staking.addPool(lcdot);

        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 200_000 ether);
        staking.stake(0, 200_000 ether);
        vm.stopPrank();

        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        vm.startPrank(ADMIN);
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2ldotConvertor));

        vm.expectRevert("convertor is not matched");
        staking.resetPoolConvertor(0, dot2ldotConvertor);

        vm.expectRevert("convertor is not matched");
        staking.resetPoolConvertor(0, lcdot2wtdotConvertor);
    }

    function test_resetPoolConvertor_works() public {
        lcdot.transfer(ALICE, 1_000_000 ether);

        vm.prank(ADMIN);
        staking.addPool(lcdot);

        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 200_000 ether);
        staking.stake(0, 200_000 ether);
        vm.stopPrank();

        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        vm.prank(ADMIN);
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2ldotConvertor));

        // mock pool convertor is not set
        uint256 poolId = 0;
        uint256 slot = stdstore.target(address(staking)).sig("poolConvertors(uint256)").with_key(poolId).depth(0).find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(address(0)));
        vm.store(address(staking), loc, zero);
        assertEq(address(staking.poolConvertors(0)), address(0));

        vm.prank(ADMIN);
        staking.resetPoolConvertor(0, lcdot2ldotConvertor);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2ldotConvertor));
    }

    function test_stake_revertZeroAmount() public {
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        vm.expectRevert("cannot stake 0");
        staking.stake(0, 0);
    }

    function test_stake_revertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.stake(0, 100);
    }

    function test_stake_revertPoolConvertorNotSet() public {
        lcdot.transfer(ALICE, 1_000_000 ether);
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);

        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 200_000 ether);
        staking.stake(0, 200_000 ether);
        vm.stopPrank();

        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);

        vm.prank(ADMIN);
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 8e18);
        assertEq(address(staking.poolConvertors(0)), address(lcdot2ldotConvertor));

        // mock pool convertor is not set
        uint256 poolId = 0;
        uint256 slot = stdstore.target(address(staking)).sig("poolConvertors(uint256)").with_key(poolId).depth(0).find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(address(0)));
        vm.store(address(staking), loc, zero);
        assertEq(address(staking.poolConvertors(0)), address(0));

        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 200_000 ether);
        vm.expectRevert("pool convertor is not set");
        staking.stake(0, 200_000 ether);
        vm.stopPrank();
    }

    function test_stake_works() public {
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
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE add share to pool#0, which hasn't been converted yet.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 200_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 200_000 ether);
        staking.stake(0, 200_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 200_000 ether);
        assertEq(staking.shares(0, ALICE), 200_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 200_000 ether);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
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
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        assertEq(staking.totalShares(0), 200_000 ether);
        assertEq(staking.shares(0, ALICE), 200_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 1_600_000 ether);
        assertEq(staking.rewards(0, ALICE, dot), 0);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE stake LCDOT to pool#0 after conversion, now the liquidCrowdloan redeem token is still DOT.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 500_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 500_000 ether);
        staking.stake(0, 500_000 ether);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 700_000 ether);
        assertEq(staking.shares(0, ALICE), 700_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 5_600_000 ether);
        assertEq(staking.rewards(0, ALICE, dot), 500_000 ether);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // simulate the exchange rate of LDOT to DOT from 8:1 increases to 5:1
        stdstore.target(address(homa)).sig("getExchangeRate()").checked_write(1e18 / 5);
        assertEq(homa.getExchangeRate(), 1e18 / 5);

        // ALICE stake more LCDOT to pool#0, but get less share amount than before.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 100_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 62_500 ether);
        staking.stake(0, 100_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 762_500 ether);
        assertEq(staking.shares(0, ALICE), 762_500 ether);
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
        emit Stake(ALICE, 0, 50_000 ether);
        staking.stake(0, 100_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 812_500 ether);
        assertEq(staking.shares(0, ALICE), 812_500 ether);
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
        vm.expectRevert("LCDOT2LDOTConvertor: unsupported convert");
        staking.stake(0, 100_000 ether);
        vm.stopPrank();
        vm.revertTo(snapId2);
    }

    function test_stake_afterConvert2WTDOT() public {
        lcdot.transfer(ALICE, 1_000_000 ether);
        dot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        staking.addPool(dot);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(staking.totalShares(1), 0);
        assertEq(staking.shares(1, ALICE), 0);
        assertEq(dot.balanceOf(address(staking)), 0);

        // ALICE add share to pool#0 and pool#1, which hasn't been converted yet.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 100_000 ether);
        dot.approve(address(staking), 100_000 ether);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 0, 100_000 ether);
        staking.stake(0, 100_000 ether);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 1, 100_000 ether);
        staking.stake(1, 100_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 100_000 ether);
        assertEq(staking.shares(0, ALICE), 100_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 100_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        assertEq(staking.totalShares(1), 100_000 ether);
        assertEq(staking.shares(1, ALICE), 100_000 ether);
        assertEq(dot.balanceOf(address(staking)), 100_000 ether);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);
        assertEq(wtdot.balanceOf(address(staking)), 0);

        // convert pool#0 & pool#1 to WTDOT pool
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        vm.startPrank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, IERC20(address(wtdot)), 100_000 ether, 90_000 ether);
        staking.convertLSTPool(0, lcdot2wtdotConvertor);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(1, dot, IERC20(address(wtdot)), 100_000 ether, 90_000 ether);
        staking.convertLSTPool(1, dot2wtdotConvertor);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 100_000 ether);
        assertEq(staking.shares(0, ALICE), 100_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 9e17);
        assertEq(staking.totalShares(1), 100_000 ether);
        assertEq(staking.shares(1, ALICE), 100_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 9e17);
        assertEq(wtdot.balanceOf(address(staking)), 180_000 ether);

        // ALICE stake LCDOT to pool#0 after conversion.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 100_000 ether);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 0, 100_000 ether);
        staking.stake(0, 100_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 200_000 ether);
        assertEq(staking.shares(0, ALICE), 200_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 270_000 ether);

        // ALICE stake DOT to pool#1 after conversion.
        vm.startPrank(ALICE);
        dot.approve(address(staking), 100_000 ether);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 1, 100_000 ether);
        staking.stake(1, 100_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(1), 200_000 ether);
        assertEq(staking.shares(1, ALICE), 200_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 360_000 ether);
    }

    function test_stake_stakeWTDOTToWTDOTPool() public {
        tdot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtdot)));
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 0);

        // ALICE stake WTDOT to WTDOT pool
        vm.startPrank(ALICE);
        tdot.approve(address(wtdot), 100_000 ether);
        uint256 stakeAmount = wtdot.deposit(100_000 ether);
        wtdot.approve(address(staking), stakeAmount);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 0, 100_000 ether);
        staking.stake(0, 100_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 100_000 ether);
        assertEq(staking.shares(0, ALICE), 100_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 900_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 100_000 ether);

        // mock the hold TDOT increased of WrappedTDOT
        tdot.transfer(address(wtdot), 25_000 ether);
        assertEq(wtdot.depositRate(), 8e17);

        // ALICE stake WTDOT to WTDOT pool
        vm.startPrank(ALICE);
        tdot.approve(address(wtdot), 100_000 ether);
        uint256 stakeAmount1 = wtdot.deposit(100_000 ether);
        wtdot.approve(address(staking), stakeAmount1);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 0, 80_000 ether);
        staking.stake(0, stakeAmount1);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 180_000 ether);
        assertEq(staking.shares(0, ALICE), 180_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 800_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 180_000 ether);
    }

    function test_unstake_RevertZeroAmount() public {
        vm.expectRevert("cannot unstake 0");
        staking.unstake(0, 0);
    }

    function test_unstake_RevertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.unstake(0, 100);
    }

    function test_unstake_works() public {
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
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE stake some share to pool#0
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 1_000_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 200_000 ether);
        staking.stake(0, 200_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 200_000 ether);
        assertEq(staking.shares(0, ALICE), 200_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 200_000 ether);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE unstake some share
        vm.warp(1_689_501_000);
        vm.prank(ALICE);
        emit Unstake(ALICE, 0, 50_000 ether);
        staking.unstake(0, 50_000 ether);
        assertEq(staking.totalShares(0), 150_000 ether);
        assertEq(staking.shares(0, ALICE), 150_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 150_000 ether);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.rewards(0, ALICE, dot), 500_000 ether);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // convert pool to LDOT
        dot.transfer(address(liquidCrowdloan), 150_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, ldot, 150_000 ether, 1_200_000 ether);
        staking.convertLSTPool(0, lcdot2ldotConvertor);
        assertEq(staking.totalShares(0), 150_000 ether);
        assertEq(staking.shares(0, ALICE), 150_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 1_200_000 ether);
        assertEq(staking.rewards(0, ALICE, dot), 500_000 ether);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // ALICE unstake some share
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit Unstake(ALICE, 0, 100_000 ether);
        staking.unstake(0, 100_000 ether);

        assertEq(staking.totalShares(0), 50_000 ether);
        assertEq(staking.shares(0, ALICE), 50_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 400_000 ether);
        assertEq(staking.rewards(0, ALICE, dot), 500_000 ether);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // ALICE exit
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit Unstake(ALICE, 0, 50_000 ether);
        emit ClaimReward(ALICE, 0, dot, 500_000 ether);
        staking.exit(0);

        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 500_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.rewards(0, ALICE, dot), 0);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, (500 ether * 1000 * 1e18) / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);
    }

    function test_unstake_unstakeWTDOTFromWTDOTPool() public {
        tdot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtdot)));
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 0);

        // ALICE stake WTDOT to WTDOT pool
        vm.startPrank(ALICE);
        tdot.approve(address(wtdot), 1_000_000 ether);
        uint256 stakeAmount = wtdot.deposit(1_000_000 ether);
        wtdot.approve(address(staking), stakeAmount);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 0, 1_000_000 ether);
        staking.stake(0, 1_000_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(ALICE)), 0);

        // ALICE unstake WTDOT from WTDOT pool
        vm.prank(ALICE);
        vm.expectEmit(true, false, false, true);
        emit Unstake(ALICE, 0, 100_000 ether);
        staking.unstake(0, 100_000 ether);
        assertEq(staking.totalShares(0), 900_000 ether);
        assertEq(staking.shares(0, ALICE), 900_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 0 ether);
        assertEq(wtdot.balanceOf(address(staking)), 900_000 ether);
        assertEq(wtdot.balanceOf(address(ALICE)), 100_000 ether);
    }

    function test_unstake_unstakeWTDOTFromConvert2WTDOTPool() public {
        dot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.prank(ADMIN);
        staking.addPool(dot);
        vm.startPrank(ALICE);
        dot.approve(address(staking), 1_000_000 ether);
        staking.stake(0, 1_000_000 ether);
        vm.stopPrank();

        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, dot, IERC20(address(wtdot)), 1_000_000 ether, 900_000 ether);
        staking.convertLSTPool(0, dot2wtdotConvertor);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 9e17);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 900_000 ether);
        assertEq(dot.balanceOf(address(ALICE)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 0);
        assertEq(wtdot.balanceOf(address(ALICE)), 0);

        // ALICE stake WTDOT from the WTDOT pool which converted from DOT pool
        vm.prank(ALICE);
        vm.expectEmit(true, false, false, true);
        emit Unstake(ALICE, 0, 100_000 ether);
        staking.unstake(0, 100_000 ether);
        assertEq(staking.totalShares(0), 900_000 ether);
        assertEq(staking.shares(0, ALICE), 900_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 810_000 ether);
        assertEq(dot.balanceOf(address(ALICE)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 0);
        assertEq(wtdot.balanceOf(address(ALICE)), 90_000 ether);

        // ALICE stake WTDOT from the WTDOT pool which converted from DOT pool
        vm.prank(ALICE);
        vm.expectEmit(true, false, false, true);
        emit Unstake(ALICE, 0, 100_000 ether);
        staking.unstake(0, 100_000 ether);
        assertEq(staking.totalShares(0), 800_000 ether);
        assertEq(staking.shares(0, ALICE), 800_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 720_000 ether);
        assertEq(dot.balanceOf(address(ALICE)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 0);
        assertEq(wtdot.balanceOf(address(ALICE)), 180_000 ether);
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
        staking.convertLSTPool(0, lcdot2ldotConvertor);
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
        vm.expectRevert("LCDOT2LDOTConvertor: unsupported convert");
        staking.stakeTo(0, 100_000 ether, BOB);
        vm.stopPrank();
        vm.revertTo(snapId2);
    }
}
