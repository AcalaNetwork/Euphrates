// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/StableAssetStakeUtil.sol";
import "../src/UpgradeableStakingLSTV2.sol";
import "../src/WrappedTDOT.sol";
import "../src/WrappedTUSD.sol";
import "../src/IWrappedStableAssetShare.sol";
import "./MockHoma.sol";
import "./MockLiquidCrowdloan.sol";
import "./MockStableAsset.sol";
import "./MockToken.sol";

contract StableAssetStakeUtilTest is Test {
    using stdStorage for StdStorage;

    event Stake(address indexed account, uint256 poolId, uint256 amount);

    UpgradeableStakingLSTV2 public staking;
    MockHoma public homa;
    MockStableAssetV2 public stableAsset;
    MockLiquidCrowdloan public liquidCrowdloan;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;
    IERC20 public usdcet;
    IERC20 public usdt;
    IERC20 public tusd;
    WrappedTDOT public wtdot;
    WrappedTUSD public wtusd;
    StableAssetStakeUtil public util;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);
    address public BOB = address(0x3333);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        lcdot = IERC20(address(new MockToken("Acala LcDOT", "LcDOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether)));
        tdot = IERC20(address(new MockToken("Taiga tDOT", "tDOT", 1_000_000_000 ether)));
        usdcet = IERC20(address(new MockToken("Wormhole USDCet", "USDCet", 1_000_000_000 ether)));
        usdt = IERC20(address(new MockToken("Asset Hub USDT", "USDT", 1_000_000_000 ether)));
        tusd = IERC20(address(new MockToken("Taiga tUSD", "tUSD", 1_000_000_000 ether)));

        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAssetV2(
            address(dot),
            address(ldot),
            address(tdot),
            address(homa),
            address(usdcet),
            address(usdt),
            address(tusd)
        );
        liquidCrowdloan = new MockLiquidCrowdloan(
            address(lcdot),
            address(dot),
            1e18
        );
        wtdot = new WrappedTDOT(address(tdot));
        wtusd = new WrappedTUSD(address(tusd));

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

        util = new StableAssetStakeUtil(
            address(staking),
            address(stableAsset),
            address(homa),
            address(ldot)
        );
    }

    function test_mintAndStake_revertInvalidStableAssetPool() public {
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtusd)));
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = 0;
        vm.expectRevert("StableAssetStakeUtil: invalid stable asset pool");
        util.mintAndStake(2, amounts, tusd, wtusd, 0);
    }

    function test_mintAndStake_revertInvalidAssetsAmount() public {
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtusd)));
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = 0;
        vm.expectRevert("MockStableAsset: invalid amounts");
        util.mintAndStake(1, amounts, tusd, wtusd, 0);
    }

    function test_mintAndStake_revertZeroMintedShareAmount() public {
        usdcet.transfer(ALICE, 1_000_000 ether);
        usdt.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtusd)));

        vm.startPrank(ALICE);
        usdcet.approve(address(util), 1_000_000 ether);
        usdt.approve(address(util), 1_000_000 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000 ether;
        amounts[1] = 1_000_000 ether;
        vm.expectRevert("StableAssetStakeUtil: zero minted share amount is not allowed");

        // StableAsset pool#1's share token is tUSD, not tDOT
        util.mintAndStake(1, amounts, tdot, wtusd, 0);
    }

    function test_mintAndStake_revertZeroWrappedShareTokenAmount() public {
        usdcet.transfer(ALICE, 1_000_000 ether);
        usdt.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtusd)));

        vm.startPrank(ALICE);
        usdcet.approve(address(util), 1_000_000 ether);
        usdt.approve(address(util), 1_000_000 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000 ether;
        amounts[1] = 1_000_000 ether;
        vm.expectRevert(stdError.arithmeticError);

        // tUSD can be wrapper by WTUSD, not WTDOT
        util.mintAndStake(1, amounts, tusd, IWrappedStableAssetShare(address(wtdot)), 0);
    }

    function test_mintAndStake_revertEuphratesPoolNotMatch() public {
        usdcet.transfer(ALICE, 1_000_000 ether);
        usdt.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(tusd);

        vm.startPrank(ALICE);
        usdcet.approve(address(util), 1_000_000 ether);
        usdt.approve(address(util), 1_000_000 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000 ether;
        amounts[1] = 1_000_000 ether;
        vm.expectRevert(stdError.arithmeticError);

        // Euphrates pool#0's share token is tUSD, not WTUSD
        util.mintAndStake(1, amounts, tusd, wtusd, 0);
    }

    function test_mintAndStake_TUSD() public {
        usdcet.transfer(ALICE, 1_000_000 ether);
        usdt.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtusd)));

        assertEq(usdcet.balanceOf(ALICE), 1_000_000 ether);
        assertEq(usdt.balanceOf(ALICE), 1_000_000 ether);
        assertEq(tusd.balanceOf(ALICE), 0);
        assertEq(wtusd.balanceOf(ALICE), 0);
        assertEq(tusd.balanceOf(address(staking)), 0);
        assertEq(wtusd.balanceOf(address(staking)), 0);
        assertEq(tusd.balanceOf(address(wtusd)), 0);
        assertEq(IERC20(address(wtusd)).totalSupply(), 0);
        assertEq(staking.shares(0, ALICE), 0);

        // ALICE mint tUSD and stake to WTUSD pool by StableAssetStakeUtil.mintAndStake
        vm.startPrank(ALICE);
        usdcet.approve(address(util), 1_000_000 ether);
        usdt.approve(address(util), 1_000_000 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000 ether;
        amounts[1] = 1_000_000 ether;
        emit Stake(ALICE, 0, 2_000_000 ether);
        util.mintAndStake(1, amounts, tusd, wtusd, 0);
        vm.stopPrank();

        assertEq(usdcet.balanceOf(ALICE), 0);
        assertEq(usdt.balanceOf(ALICE), 0);
        assertEq(tusd.balanceOf(ALICE), 0);
        assertEq(wtusd.balanceOf(ALICE), 0);
        assertEq(tusd.balanceOf(address(staking)), 0);
        assertEq(wtusd.balanceOf(address(staking)), 2_000_000 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 2_000_000 ether);
        assertEq(IERC20(address(wtusd)).totalSupply(), 2_000_000 ether);
        assertEq(staking.shares(0, ALICE), 2_000_000 ether);

        // mock the hold TUSD increased of WrappedTUSD
        tusd.transfer(address(wtusd), 500_000 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 2_500_000 ether);
        assertEq(IERC20(address(wtusd)).totalSupply(), 2_000_000 ether);

        usdcet.transfer(BOB, 1_000_000 ether);
        usdt.transfer(BOB, 1_000_000 ether);
        assertEq(usdcet.balanceOf(BOB), 1_000_000 ether);
        assertEq(usdt.balanceOf(BOB), 1_000_000 ether);
        assertEq(tusd.balanceOf(BOB), 0);
        assertEq(wtusd.balanceOf(BOB), 0);
        assertEq(staking.shares(0, BOB), 0);

        // BOB mint tUSD and stake to WTUSD pool by StableAssetStakeUtil.mintAndStake
        vm.startPrank(BOB);
        usdcet.approve(address(util), 1_000_000 ether);
        usdt.approve(address(util), 1_000_000 ether);
        uint256[] memory amounts1 = new uint256[](2);
        amounts1[0] = 1_000_000 ether;
        amounts1[1] = 1_000_000 ether;
        emit Stake(BOB, 0, 1_600_000 ether);
        util.mintAndStake(1, amounts1, tusd, wtusd, 0);
        vm.stopPrank();

        assertEq(usdcet.balanceOf(BOB), 0);
        assertEq(usdt.balanceOf(BOB), 0);
        assertEq(tusd.balanceOf(BOB), 0);
        assertEq(wtusd.balanceOf(BOB), 0);
        assertEq(tusd.balanceOf(address(staking)), 0);
        assertEq(wtusd.balanceOf(address(staking)), 3_600_000 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 4_500_000 ether);
        assertEq(IERC20(address(wtusd)).totalSupply(), 3_600_000 ether);
        assertEq(staking.shares(0, BOB), 1_600_000 ether);
    }

    function test_mintAndStake_TDOT() public {
        dot.transfer(ALICE, 1_000_000 ether);
        ldot.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtdot)));

        assertEq(dot.balanceOf(ALICE), 1_000_000 ether);
        assertEq(ldot.balanceOf(ALICE), 1_000_000 ether);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(wtdot)), 0);
        assertEq(IERC20(address(wtdot)).totalSupply(), 0);
        assertEq(staking.shares(0, ALICE), 0);

        // ALICE mint TDOT and stake to WTDOT pool by StableAssetStakeUtil.mintAndStake
        vm.startPrank(ALICE);
        dot.approve(address(util), 1_000_000 ether);
        ldot.approve(address(util), 1_000_000 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000 ether;
        amounts[1] = 1_000_000 ether;
        emit Stake(ALICE, 0, 2_000_000 ether);
        util.mintAndStake(0, amounts, tdot, IWrappedStableAssetShare(address(wtdot)), 0);
        vm.stopPrank();

        assertEq(dot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(wtdot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 1_100_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 1_100_000 ether);
        assertEq(IERC20(address(wtdot)).totalSupply(), 1_100_000 ether);
        assertEq(staking.shares(0, ALICE), 1_100_000 ether);
    }

    function test_wrapAndStake_TUSD() public {
        tusd.transfer(ALICE, 1_000_000 ether);
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtusd)));

        assertEq(tusd.balanceOf(ALICE), 1_000_000 ether);
        assertEq(wtusd.balanceOf(ALICE), 0);
        assertEq(tusd.balanceOf(address(staking)), 0);
        assertEq(wtusd.balanceOf(address(staking)), 0);
        assertEq(tusd.balanceOf(address(wtusd)), 0);
        assertEq(IERC20(address(wtusd)).totalSupply(), 0);

        // ALICE wrap TUSD and stake to WTUSD pool by StableAssetStakeUtil.wrapAndStake
        vm.startPrank(ALICE);
        tusd.approve(address(util), 1_000_000 ether);
        emit Stake(ALICE, 0, 1_000_000 ether);
        util.wrapAndStake(tusd, 1_000_000 ether, wtusd, 0);
        vm.stopPrank();

        assertEq(tusd.balanceOf(ALICE), 0);
        assertEq(wtusd.balanceOf(ALICE), 0);
        assertEq(tusd.balanceOf(address(staking)), 0);
        assertEq(wtusd.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 1_000_000 ether);
        assertEq(IERC20(address(wtusd)).totalSupply(), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);

        // mock the hold TUSD increased of WrappedTUSD
        tusd.transfer(address(wtusd), 250_000 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 1_250_000 ether);
        assertEq(IERC20(address(wtusd)).totalSupply(), 1_000_000 ether);

        tusd.transfer(BOB, 1_000_000 ether);
        assertEq(tusd.balanceOf(BOB), 1_000_000 ether);
        assertEq(wtusd.balanceOf(ALICE), 0);
        assertEq(staking.shares(0, BOB), 0);

        // BOB wrap TUSD and stake to WTUSD pool by StableAssetStakeUtil.wrapAndStake
        vm.startPrank(BOB);
        tusd.approve(address(util), 1_000_000 ether);
        emit Stake(BOB, 0, 800_000 ether);
        util.wrapAndStake(tusd, 1_000_000 ether, wtusd, 0);
        vm.stopPrank();

        assertEq(tusd.balanceOf(BOB), 0);
        assertEq(wtusd.balanceOf(BOB), 0);
        assertEq(tusd.balanceOf(address(staking)), 0);
        assertEq(wtusd.balanceOf(address(staking)), 1_800_000 ether);
        assertEq(tusd.balanceOf(address(wtusd)), 2_250_000 ether);
        assertEq(IERC20(address(wtusd)).totalSupply(), 1_800_000 ether);
        assertEq(staking.shares(0, BOB), 800_000 ether);
    }
}
