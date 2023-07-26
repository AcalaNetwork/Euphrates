// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/StakingLSD.sol";
import "./MockHoma.sol";
import "./MockLiquidCrowdloan.sol";
import "./MockStableAsset.sol";
import "./MockToken.sol";

// wrapper for testing internal functions
contract StakingLSDHarness is StakingLSD {
    constructor(
        address dot,
        address lcdot,
        address ldot,
        address tdot,
        address homa,
        address stableAsset,
        address liquidCrowdloan
    ) StakingLSD(dot, lcdot, ldot, tdot, homa, stableAsset, liquidCrowdloan) {}

    function convertLcdot2Ldot(uint256 amount) public returns (uint256 convertAmount) {
        return _convertLcdot2Ldot(amount);
    }

    function convertLcdot2Tdot(uint256 amount) public returns (uint256 convertAmount) {
        return _convertLcdot2Tdot(amount);
    }
}

contract StakingLSDTest is Test {
    using stdStorage for StdStorage;

    event LSDPoolConverted(
        uint256 poolId,
        IERC20 beforeShareType,
        IERC20 afterShareType,
        uint256 beforeShareAmount,
        uint256 afterShareAmount
    );
    event Unstake(address indexed account, uint256 poolId, uint256 amount);
    event Stake(address indexed account, uint256 poolId, uint256 amount);
    event ClaimReward(address indexed account, uint256 poolId, IERC20 indexed rewardType, uint256 amount);

    StakingLSDHarness public staking;
    MockHoma public homa;
    MockStableAsset public stableAsset;
    MockLiquidCrowdloan public liquidCrowdloan;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        lcdot = IERC20(address(new MockToken("Acala LcDOT", "LcDOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether)));
        tdot = IERC20(address(new MockToken("Acala tDOT", "tDOT", 1_000_000_000 ether)));

        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAsset(address(dot), address(ldot), address(tdot));
        liquidCrowdloan = new MockLiquidCrowdloan(address(lcdot), address(dot), 1e18);

        vm.prank(ADMIN);
        staking = new StakingLSDHarness(
            address(dot),
            address(lcdot),
            address(ldot),
            address(tdot),
            address(homa),
            address(stableAsset),
            address(liquidCrowdloan)
        );
    }

    function test_convertLcdot2Ldot_revertZeroAmount() public {
        vm.expectRevert("amount shouldn't be zero");
        staking.convertLcdot2Ldot(0);
    }

    function test_convertLcdot2Ldot_liquidCrowdloanRedeemDot() public {
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000_000 ether);

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);

        // simulate redeem zero DOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        assertEq(staking.convertLcdot2Ldot(20_000_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // simulate redeem zero LDOT liquidCrowdloan
        uint256 snapId1 = vm.snapshot();
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        uint256 slot1 = stdstore.target(address(homa)).sig("getExchangeRate()").find();
        bytes32 loc1 = bytes32(slot1);
        vm.store(address(homa), loc1, zero);
        assertEq(homa.getExchangeRate(), 0);
        vm.expectRevert(stdError.divisionError);
        assertEq(staking.convertLcdot2Ldot(20_000_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId1);

        // convertion succeed
        assertEq(staking.convertLcdot2Ldot(20_000_000 ether), 160_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 160_000_000 ether);
    }

    function test_convertLcdot2Ldot_liquidCrowdloanRedeemLdot() public {
        ldot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(10e18);

        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);

        // simulate redeem zero LDOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        assertEq(staking.convertLcdot2Ldot(20_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // convertion succeed
        assertEq(staking.convertLcdot2Ldot(20_000 ether), 200_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 200_000 ether);
    }

    function test_convertLcdot2Ldot_revertLiquidCrowdloanRedeemTdot() public {
        tdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);

        vm.expectRevert("unsupported convert");
        staking.convertLcdot2Ldot(100_000 ether);
    }

    function test_convertLcdot2Tdot_revertZeroAmount() public {
        vm.expectRevert("amount shouldn't be zero");
        staking.convertLcdot2Tdot(0);
    }

    function test_convertLcdot2Tdot_liquidCrowdloanRedeemDot() public {
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000_000 ether);

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);

        // simulate redeem zero DOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        vm.expectRevert("MockStableAsset: invalid amounts");
        staking.convertLcdot2Tdot(20_000_000 ether);

        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // convertion succeed
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(staking.convertLcdot2Tdot(20_000_000 ether), 20_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 20_000_000 ether);
    }

    function test_convertLcdot2Tdot_liquidCrowdloanRedeemLdot() public {
        ldot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(8e18);

        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);

        // simulate redeem zero LDOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        vm.expectRevert("MockStableAsset: invalid amounts");
        assertEq(staking.convertLcdot2Tdot(20_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // convertion succeed
        assertEq(staking.convertLcdot2Tdot(20_000 ether), 16_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 16_000 ether);
    }

    function test_convertLcdot2Tdot_liquidCrowdloanRedeemTdot() public {
        tdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);

        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);

        // simulate redeem zero TDOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        assertEq(staking.convertLcdot2Tdot(20_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // convertion succeed
        assertEq(staking.convertLcdot2Tdot(20_000 ether), 20_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 20_000 ether);
    }

    function test_convertLcdot2Tdot_revertLiquidCrowdloanRedeemLcdot() public {
        lcdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(lcdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);

        vm.expectRevert("unsupported convert");
        staking.convertLcdot2Tdot(100_000 ether);
    }

    function test_convertLSDPool_works() public {
        // caller is not admin
        assertEq(staking.owner(), ADMIN);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.convertLSDPool(0, StakingLSD.ConvertType.Lcdot2Ldot);

        vm.startPrank(ADMIN);

        // the pool is not created.
        assertEq(address(staking.shareTypes(0)), address(0));
        vm.expectRevert("share token must be LcDOT");
        staking.convertLSDPool(0, StakingLSD.ConvertType.Lcdot2Ldot);

        staking.addPool(dot);
        staking.addPool(lcdot);
        staking.addPool(lcdot);
        assertEq(address(staking.shareTypes(0)), address(dot));
        assertEq(address(staking.shareTypes(1)), address(lcdot));
        assertEq(address(staking.shareTypes(2)), address(lcdot));

        // pool is not LcDOT pool
        vm.expectRevert("share token must be LcDOT");
        staking.convertLSDPool(0, StakingLSD.ConvertType.Lcdot2Ldot);

        // share amount is zero
        vm.expectRevert("pool is empty");
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Ldot);
        vm.stopPrank();

        // stake share LCDOT to pool#1
        lcdot.transfer(ALICE, 1_000_000 ether);
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 1_000_000 ether);
        staking.stake(1, 1_000_000 ether);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);
        vm.stopPrank();

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);

        // simulate redeem 0 DOT by LiquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        vm.prank(ADMIN);
        vm.expectRevert("exchange rate shouldn't be zero");
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Ldot);
        vm.revertTo(snapId);

        // convert LCDOT pool to LDOT pool, and liquidCrowdloan redeem token is DOT
        uint256 snapId1 = vm.snapshot();
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(1, lcdot, ldot, 1_000_000 ether, 8_000_000 ether);
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Ldot);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000 ether);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 8e18);
        vm.revertTo(snapId1);

        // convert LCDOT pool to LDOT pool, and liquidCrowdloan redeem token is LDOT
        uint256 snapId2 = vm.snapshot();
        ldot.transfer(address(liquidCrowdloan), 10_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(10e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 10e18);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(1, lcdot, ldot, 1_000_000 ether, 10_000_000 ether);
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Ldot);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 10_000_000 ether);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 10e18);
        vm.revertTo(snapId2);

        // simulate convert LCDOT pool to LDOT pool, and liquidCrowdloan redeem token is TDOT
        uint256 snapId3 = vm.snapshot();
        tdot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(tdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectRevert("unsupported convert");
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Ldot);
        vm.revertTo(snapId3);

        // convert LCDOT pool to TDOT pool, and liquidCrowdloan redeem token is DOT
        uint256 snapId4 = vm.snapshot();
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(1, lcdot, tdot, 1_000_000 ether, 1_000_000 ether);
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Tdot);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(tdot));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 1e18);
        vm.revertTo(snapId4);

        // convert LCDOT pool to TDOT pool, and liquidCrowdloan redeem token is LDOT
        uint256 snapId5 = vm.snapshot();
        ldot.transfer(address(liquidCrowdloan), 10_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(10e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 10e18);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(1, lcdot, tdot, 1_000_000 ether, 1_000_000 ether);
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Tdot);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(tdot));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 1e18);
        vm.revertTo(snapId5);

        // convert LCDOT pool to TDOT pool, and liquidCrowdloan redeem token is TDOT
        uint256 snapId6 = vm.snapshot();
        tdot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(tdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(1, lcdot, tdot, 1_000_000 ether, 1_000_000 ether);
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Tdot);
        assertEq(staking.totalShares(1), 1_000_000 ether);
        assertEq(staking.shares(1, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(tdot));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 1e18);
        vm.revertTo(snapId6);
    }

    function test_stakeBeforeShareToken_revertZeroAmount() public {
        vm.expectRevert("cannot stake 0");
        staking.stakeBeforeShareToken(0, 0);
    }

    function test_stakeBeforeShareToken_revertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.stakeBeforeShareToken(0, 100);
    }

    function test_stakeBeforeShareToken_works() public {
        vm.warp(1_689_500_000);

        dot.transfer(address(staking), 1_000_000 ether);
        lcdot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        staking.notifyRewardRule(0, dot, 1_000_000 ether, 2_000);
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
        staking.stakeBeforeShareToken(0, 200_000 ether);
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
        emit LSDPoolConverted(0, lcdot, ldot, 200_000 ether, 1_600_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.Lcdot2Ldot);
        assertEq(staking.totalShares(0), 200_000 ether);
        assertEq(staking.shares(0, ALICE), 200_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 1_600_000 ether);
        assertEq(staking.rewards(0, ALICE, dot), 0);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE stake LCDOT to pool#0 after conversion, now the liquidCrowdloan redeem token is still DOT.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 500_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 500_000 ether);
        staking.stakeBeforeShareToken(0, 500_000 ether);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 700_000 ether);
        assertEq(staking.shares(0, ALICE), 700_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 5_600_000 ether);
        assertEq(staking.rewards(0, ALICE, dot), 500_000 ether);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // simulate the exchange rate of LDOT to DOT from 8:1 increases to 5:1
        stdstore.target(address(homa)).sig("getExchangeRate()").checked_write(1e18 / 5);
        assertEq(homa.getExchangeRate(), 1e18 / 5);

        // ALICE stake more LCDOT to pool#0, but get less share amount than before.
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 100_000 ether);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 62_500 ether);
        staking.stakeBeforeShareToken(0, 100_000 ether);
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
        staking.stakeBeforeShareToken(0, 100_000 ether);
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
        vm.expectRevert("unsupported convert");
        staking.stakeBeforeShareToken(0, 100_000 ether);
        vm.stopPrank();
        vm.revertTo(snapId2);
    }

    function test_stake_revertZeroAmount() public {
        vm.expectRevert("cannot stake 0");
        staking.stake(0, 0);
    }

    function test_stake_revertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.stake(0, 100);
    }

    function test_stake_works() public {
        vm.warp(1_689_500_000);

        dot.transfer(address(staking), 1_000_000 ether);
        lcdot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        staking.notifyRewardRule(0, dot, 1_000_000 ether, 2_000);
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

        // ALICE add share to pool#0
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
        emit LSDPoolConverted(0, lcdot, ldot, 200_000 ether, 1_600_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.Lcdot2Ldot);
        assertEq(staking.totalShares(0), 200_000 ether);
        assertEq(staking.shares(0, ALICE), 200_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 1_600_000 ether);
        assertEq(staking.rewards(0, ALICE, dot), 0);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE stake extra share to pool#0, now share token is LDOT after conversion
        ldot.transfer(address(ALICE), 4_000_000 ether);
        vm.startPrank(ALICE);
        ldot.approve(address(staking), 4_000_000 ether);
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
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);
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

        dot.transfer(address(staking), 1_000_000 ether);
        lcdot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        staking.notifyRewardRule(0, dot, 1_000_000 ether, 2_000);
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
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // convert pool to LDOT
        dot.transfer(address(liquidCrowdloan), 150_000 ether);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, lcdot, ldot, 150_000 ether, 1_200_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.Lcdot2Ldot);
        assertEq(staking.totalShares(0), 150_000 ether);
        assertEq(staking.shares(0, ALICE), 150_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 1_200_000 ether);
        assertEq(staking.rewards(0, ALICE, dot), 500_000 ether);
        assertEq(staking.earned(0, ALICE, dot), 500_000 ether);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 ether * 1000 * 1e18 / 200_000 ether);
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
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 ether * 1000 * 1e18 / 200_000 ether);
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
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardPerShare(0, dot), 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500 ether);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 ether * 1000 * 1e18 / 200_000 ether);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);
    }
}
