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

    function redeemLCDOT(uint256 amount) public returns (address redeemCurrency, uint256 redeemedAmount) {
        return _redeemLCDOT(amount);
    }

    function convertLCDOT2LDOT(uint256 amount) public returns (uint256 convertAmount) {
        return _convertLCDOT2LDOT(amount);
    }

    function convertLCDOT2TDOT(uint256 amount) public returns (uint256 convertAmount) {
        return _convertLCDOT2TDOT(amount);
    }

    function convertDOT2LDOT(uint256 amount) public returns (uint256 convertAmount) {
        return _convertDOT2LDOT(amount);
    }

    function convertDOT2TDOT(uint256 amount) public returns (uint256 convertAmount) {
        return _convertDOT2TDOT(amount);
    }

    function convertLDOT2TDOT(uint256 amount) public returns (uint256 convertAmount) {
        return _convertLDOT2TDOT(amount);
    }
}

contract StakingLSDTest is Test {
    using stdStorage for StdStorage;

    event LSDPoolConverted(
        uint256 poolId,
        IERC20 beforeShareType,
        IERC20 afterShareType,
        uint256 beforeShareTokenAmount,
        uint256 afterShareTokenAmount
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

    function test_redeemLCDOT_revertZeroAmount() public {
        vm.expectRevert("amount shouldn't be zero");
        staking.redeemLCDOT(0);
    }

    function test_redeemLCDOT_toDOT() public {
        lcdot.transfer(address(staking), 100_000_000 ether);
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);

        (address redeemCurrency, uint256 redeemedAmount) = staking.redeemLCDOT(10_000_000 ether);
        assertEq(redeemCurrency, address(dot));
        assertEq(redeemedAmount, 10_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 10_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 90_000_000 ether);
    }

    function test_redeemLCDOT_toLDOT() public {
        lcdot.transfer(address(staking), 100_000_000 ether);
        ldot.transfer(address(liquidCrowdloan), 1_000_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(10e18);

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 10e18);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);

        (address redeemCurrency, uint256 redeemedAmount) = staking.redeemLCDOT(20_000_000 ether);
        assertEq(redeemCurrency, address(ldot));
        assertEq(redeemedAmount, 200_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 200_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 80_000_000 ether);
    }

    function test_redeemLCDOT_toTDOT() public {
        lcdot.transfer(address(staking), 100_000_000 ether);
        tdot.transfer(address(liquidCrowdloan), 101_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(101e16);

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(tdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 101e16);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);

        (address redeemCurrency, uint256 redeemedAmount) = staking.redeemLCDOT(10_000_000 ether);
        assertEq(redeemCurrency, address(tdot));
        assertEq(redeemedAmount, 10_100_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 10_100_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 90_000_000 ether);
    }

    function test_convertDOT2LDOT_revertZeroAmount() public {
        vm.expectRevert("amount shouldn't be zero");
        staking.convertDOT2LDOT(0);
    }

    function test_convertDOT2LDOT() public {
        dot.transfer(address(staking), 100_000_000 ether);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(dot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);

        assertEq(staking.convertDOT2LDOT(20_000_000 ether), 160_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 80_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 160_000_000 ether);
    }

    function test_convertDOT2TDOT_revertZeroAmount() public {
        vm.expectRevert("amount shouldn't be zero");
        staking.convertDOT2TDOT(0);
    }

    function test_convertDOT2TDOT() public {
        dot.transfer(address(staking), 100_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);

        assertEq(staking.convertDOT2TDOT(10_000_000 ether), 10_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 90_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 10_000_000 ether);
    }

    function test_convertLDOT2TDOT_revertZeroAmount() public {
        vm.expectRevert("amount shouldn't be zero");
        staking.convertLDOT2TDOT(0);
    }

    function test_convertLDOT2TDOT() public {
        ldot.transfer(address(staking), 100_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);

        assertEq(staking.convertLDOT2TDOT(10_000_000 ether), 1_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 90_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 1_000_000 ether);
    }

    function test_convertLCDOT2LDOT_revertZeroAmount() public {
        vm.expectRevert("amount shouldn't be zero");
        staking.convertLCDOT2LDOT(0);
    }

    function test_convertLCDOT2LDOT_liquidCrowdloanRedeemDot() public {
        lcdot.transfer(address(staking), 100_000_000 ether);
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(homa.getExchangeRate(), 1e18 / 8);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);

        // simulate redeem 0 DOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        vm.expectRevert("amount shouldn't be zero");
        assertEq(staking.convertLCDOT2LDOT(20_000_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // simulate mint 0 LDOT by Homa
        uint256 snapId1 = vm.snapshot();
        uint256 slot1 = stdstore.target(address(homa)).sig("getExchangeRate()").find();
        bytes32 loc1 = bytes32(slot1);
        vm.store(address(homa), loc1, zero);
        assertEq(homa.getExchangeRate(), 0);
        vm.expectRevert(stdError.divisionError);
        assertEq(staking.convertLCDOT2LDOT(20_000_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId1);

        // convertion succeed
        assertEq(staking.convertLCDOT2LDOT(20_000_000 ether), 160_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 160_000_000 ether);
    }

    function test_convertLCDOT2LDOT_liquidCrowdloanRedeemLdot() public {
        ldot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(10e18);

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 10e18);
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
        assertEq(staking.convertLCDOT2LDOT(20_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // convertion succeed
        assertEq(staking.convertLCDOT2LDOT(20_000 ether), 200_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(ldot.balanceOf(address(staking)), 200_000 ether);
    }

    function test_convertLCDOT2LDOT_LiquidCrowdloanRedeemTdot_revertUnsupported() public {
        tdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);

        vm.expectRevert("unsupported convert");
        staking.convertLCDOT2LDOT(100_000 ether);
    }

    function test_convertLCDOT2TDOT_revertZeroAmount() public {
        vm.expectRevert("amount shouldn't be zero");
        staking.convertLCDOT2TDOT(0);
    }

    function test_convertLCDOT2TDOT_liquidCrowdloanRedeemDot() public {
        dot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000_000 ether);

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);

        // simulate redeem 0 DOT by liquidCrowdloan
        uint256 snapId = vm.snapshot();
        uint256 slot = stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").find();
        bytes32 loc = bytes32(slot);
        bytes32 zero = bytes32(abi.encode(0));
        vm.store(address(liquidCrowdloan), loc, zero);
        assertEq(liquidCrowdloan.redeemExchangeRate(), 0);
        vm.expectRevert("amount shouldn't be zero");
        staking.convertLCDOT2TDOT(20_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // convertion succeed
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);
        assertEq(staking.convertLCDOT2TDOT(20_000_000 ether), 20_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 20_000_000 ether);
    }

    function test_convertLCDOT2TDOT_liquidCrowdloanRedeemLdot() public {
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
        vm.expectRevert("amount shouldn't be zero");
        assertEq(staking.convertLCDOT2TDOT(20_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 100_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // convertion succeed
        assertEq(staking.convertLCDOT2TDOT(20_000 ether), 16_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 16_000 ether);
    }

    function test_convertLCDOT2TDOT_liquidCrowdloanRedeemTdot() public {
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
        assertEq(staking.convertLCDOT2TDOT(20_000 ether), 0);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        vm.revertTo(snapId);

        // convertion succeed
        assertEq(staking.convertLCDOT2TDOT(20_000 ether), 20_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 20_000 ether);
    }

    function test_convertLCDOT2TDOT_LiquidCrowdloanRedeemLcdot_revertUnsupported() public {
        lcdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        lcdot.transfer(address(staking), 100_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(lcdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(1e18);

        vm.expectRevert("unsupported convert");
        staking.convertLCDOT2TDOT(100_000 ether);
    }

    function test_convertLSDPool_revertNotOwner() public {
        assertEq(staking.owner(), ADMIN);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
    }

    function test_convertLSDPool_revertEmptyPool() public {
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        vm.expectRevert("pool is empty");
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
    }

    function test_convertLSDPool_revertDismatchShareType() public {
        vm.startPrank(ADMIN);
        staking.addPool(dot);
        staking.addPool(lcdot);
        staking.addPool(ldot);
        vm.stopPrank();

        dot.approve(address(staking), 1_000_000 ether);
        lcdot.approve(address(staking), 1_000_000 ether);
        ldot.approve(address(staking), 1_000_000 ether);
        staking.stake(0, 100_000 ether);
        staking.stake(1, 100_000 ether);
        staking.stake(2, 100_000 ether);

        vm.startPrank(ADMIN);
        vm.expectRevert("share token must be LcDOT");
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
        vm.expectRevert("share token must be LcDOT");
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2TDOT);
        vm.expectRevert("share token must be DOT");
        staking.convertLSDPool(1, StakingLSD.ConvertType.DOT2LDOT);
        vm.expectRevert("share token must be DOT");
        staking.convertLSDPool(1, StakingLSD.ConvertType.DOT2TDOT);
        vm.stopPrank();
    }

    function test_convertLSDPool_LCDOT2LDOT() public {
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
        vm.expectRevert("amount shouldn't be zero");
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
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
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
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
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, lcdot, ldot, 1_000_000 ether, 8_000_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 8e18);

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
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
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, lcdot, ldot, 1_000_000 ether, 10_000_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 10_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 10e18);
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
        vm.prank(ADMIN);
        vm.expectRevert("unsupported convert");
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
        vm.revertTo(snapId4);
    }

    function test_convertLSDPool_LCDOT2TDOT() public {
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
        vm.stopPrank();

        assertEq(liquidCrowdloan.getRedeemCurrency(), address(dot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 1e18);

        // simulate convert LCDOT pool to TDOT pool, and liquidCrowdloan redeem token is DOT
        uint256 snapId = vm.snapshot();
        dot.transfer(address(liquidCrowdloan), 1_000_000 ether);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, lcdot, tdot, 1_000_000 ether, 1_000_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2TDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(tdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 1e18);
        vm.revertTo(snapId);

        // simulate convert LCDOT pool to TDOT pool, and liquidCrowdloan redeem token is LDOT
        uint256 snapId1 = vm.snapshot();
        ldot.transfer(address(liquidCrowdloan), 10_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(ldot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(10e18);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(ldot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 10e18);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, lcdot, tdot, 1_000_000 ether, 1_000_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2TDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(tdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 1e18);
        vm.revertTo(snapId1);

        // simulate convert LCDOT pool to TDOT pool, and liquidCrowdloan redeem token is TDOT
        uint256 snapId2 = vm.snapshot();
        tdot.transfer(address(liquidCrowdloan), 100_000_000 ether);
        stdstore.target(address(liquidCrowdloan)).sig("getRedeemCurrency()").checked_write(address(tdot));
        stdstore.target(address(liquidCrowdloan)).sig("redeemExchangeRate()").checked_write(101e16);
        assertEq(liquidCrowdloan.getRedeemCurrency(), address(tdot));
        assertEq(liquidCrowdloan.redeemExchangeRate(), 101e16);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, lcdot, tdot, 1_000_000 ether, 1_010_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2TDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 1_010_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(tdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 101e16);
        vm.revertTo(snapId2);
    }

    function test_convertLSDPool_DOT2LDOT() public {
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
        staking.convertLSDPool(0, StakingLSD.ConvertType.DOT2LDOT);
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
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, dot, ldot, 1_000_000 ether, 8_000_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.DOT2LDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 8e18);

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSDPool(0, StakingLSD.ConvertType.DOT2LDOT);
        vm.revertTo(snapId2);
    }

    function test_convertLSDPool_DOT2TDOT() public {
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
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(0));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 0);
        vm.stopPrank();

        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, dot, tdot, 1_000_000 ether, 1_000_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.DOT2TDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(tdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 1e18);

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSDPool(0, StakingLSD.ConvertType.DOT2TDOT);
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
        emit LSDPoolConverted(0, lcdot, ldot, 200_000 ether, 1_600_000 ether);
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
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
        vm.expectRevert("unsupported convert");
        staking.stake(0, 100_000 ether);
        vm.stopPrank();
        vm.revertTo(snapId2);
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
        staking.convertLSDPool(0, StakingLSD.ConvertType.LCDOT2LDOT);
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
