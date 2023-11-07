// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/UpgradeableStakingLST.sol";
import "../src/WrappedTDOT.sol";
import "./MockHoma.sol";
import "./MockLiquidCrowdloan.sol";
import "./MockStableAsset.sol";
import "./MockToken.sol";

contract UpgradeableStakingLSTHarness is UpgradeableStakingLST {
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

    function convertTDOT2WTDOT(uint256 amount) public returns (uint256 convertAmount) {
        return _convertTDOT2WTDOT(amount);
    }

    function convertWTDOT2TDOT(uint256 amount) public returns (uint256 convertAmount) {
        return _convertWTDOT2TDOT(amount);
    }
}

contract UpgradeableStakingLSTTest is Test {
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

    UpgradeableStakingLSTHarness public staking;
    MockHoma public homa;
    MockStableAsset public stableAsset;
    MockLiquidCrowdloan public liquidCrowdloan;
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
        wtdot = new WrappedTDOT(address(tdot));

        staking = new UpgradeableStakingLSTHarness();
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

    function test_getDeductionInstantlyByAdvancedStake() public {
        // 1. initialize states
        vm.warp(1_689_500_000);
        aca.transfer(ADMIN, 1_000_000 ether);
        dot.transfer(ALICE, 1_000 ether);
        dot.transfer(BOB, 1_000 ether);
        address[] memory subAccounts = new address[](1000);
        uint256 subStakeAmount = 1 ether;
        for (uint256 i = 0; i < subAccounts.length; i++) {
            subAccounts[i] = address(uint160(i + 1));
            dot.transfer(subAccounts[i], subStakeAmount);
        }

        vm.startPrank(ADMIN);
        staking.addPool(dot);
        aca.approve(address(staking), 1_000_000 ether);
        staking.updateRewardRule(0, aca, 1_000 ether, 1_689_501_000);
        staking.setRewardsDeductionRate(0, uint256(1e18) / 5); // 20% deduction
        vm.stopPrank();

        vm.startPrank(ALICE);
        dot.approve(address(staking), 1_000 ether);
        staking.stake(0, 1_000 ether);
        vm.stopPrank();

        vm.warp(1_689_500_100);
        assertEq(staking.earned(0, ALICE, aca), 100_000 ether);

        // simulate stake share before deduction generate to gain from deduction restribute
        uint256 snapId = vm.snapshot();
        vm.startPrank(BOB);
        dot.approve(address(staking), 1_000 ether);
        staking.stake(0, 1_000 ether);
        vm.stopPrank();

        assertEq(staking.earned(0, BOB, aca), 0 ether);
        vm.prank(ALICE);
        staking.claimRewards(0);

        // decution is 20_000 ether, BOB get 10_000 ether from deduction redistribution
        assertEq(staking.earned(0, BOB, aca), 10_000 ether);

        // BOB claim reward to receive 8_000 ether
        assertEq(aca.balanceOf(BOB), 0 ether);
        vm.prank(BOB);
        staking.claimRewards(0);
        assertEq(aca.balanceOf(BOB), 8_000 ether);
        vm.revertTo(snapId);

        // simulate stake by sub accounts seperately before deduction generate
        // stake by 1000 accounts, which stake 1 ether
        for (uint256 i = 0; i < subAccounts.length; i++) {
            vm.startPrank(subAccounts[i]);
            dot.approve(address(staking), subStakeAmount);
            staking.stake(0, subStakeAmount);
            vm.stopPrank();

            assertEq(staking.shares(0, subAccounts[i]), subStakeAmount);
            assertEq(staking.earned(0, subAccounts[i], aca), 0 ether);
        }

        vm.prank(ALICE);
        staking.claimRewards(0);

        uint256 totalEarned;
        for (uint256 i = 0; i < subAccounts.length; i++) {
            totalEarned = totalEarned + staking.earned(0, subAccounts[i], aca);
        }
        assertEq(totalEarned, 10_000 ether);
        console.log("total earned deduction which generate by ALICE: ", totalEarned);

        uint256 loop = 20;
        uint256[] memory receivedProfitByLoop = new uint256[](loop);

        for (uint256 j = 0; j < loop; j++) {
            for (uint256 i = 0; i < subAccounts.length; i++) {
                // each account claimRewards to generate new deduction
                uint256 beforeReceived = aca.balanceOf(subAccounts[i]);
                vm.prank(subAccounts[i]);
                staking.claimRewards(0);
                uint256 afterReceived = aca.balanceOf(subAccounts[i]);
                receivedProfitByLoop[j] += afterReceived - beforeReceived;
            }

            uint256 totalReceivedProfit;
            for (uint256 i = 0; i <= j; i++) {
                totalReceivedProfit += receivedProfitByLoop[i];
            }

            console.log(
                "on loop#%s, profit is %s and total profit is %s", j, receivedProfitByLoop[j], totalReceivedProfit
            );
        }

        // output:
        // total earned deduction which generate by ALICE:  10000000000000000000000
        // on loop#0, profit is 8413231408258615576616 and total profit is 8413231408258615576616
        // on loop#1, profit is 457573095453811019314 and total profit is 8870804503712426595930
        // on loop#2, profit is 17521480582762029503 and total profit is 8888325984295188625433
        // on loop#3, profit is 547124116408170309 and total profit is 8888873108411596795742
        // on loop#4, profit is 15355399738316093 and total profit is 8888888463811335111835
        // on loop#5, profit is 413693173506145 and total profit is 8888888877504508617980
        // on loop#6, profit is 11078200136216 and total profit is 8888888888582708754196
        // on loop#7, profit is 297916522380 and total profit is 8888888888880625276576
        // on loop#8, profit is 8036869046 and total profit is 8888888888888662145622
        // on loop#9, profit is 216548626 and total profit is 8888888888888878694248
        // on loop#10, profit is 5433845 and total profit is 8888888888888884128093
        // on loop#11, profit is 30070 and total profit is 8888888888888884158163
        // on loop#12, profit is 0 and total profit is 8888888888888884158163
        // on loop#13, profit is 0 and total profit is 8888888888888884158163
        // on loop#14, profit is 0 and total profit is 8888888888888884158163
        // on loop#15, profit is 0 and total profit is 8888888888888884158163
        // on loop#16, profit is 0 and total profit is 8888888888888884158163
        // on loop#17, profit is 0 and total profit is 8888888888888884158163
        // on loop#18, profit is 0 and total profit is 8888888888888884158163
        // on loop#19, profit is 0 and total profit is 8888888888888884158163
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

    function test_convertDOT2TDOT_halfDOTMintLDOT() public {
        dot.transfer(address(staking), staking.HOMA_MINT_THRESHOLD() * 2);
        assertEq(dot.balanceOf(address(staking)), staking.HOMA_MINT_THRESHOLD() * 2);
        assertEq(tdot.balanceOf(address(staking)), 0);

        assertEq(staking.convertDOT2TDOT(staking.HOMA_MINT_THRESHOLD() * 2), 90_000_000_000);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 90_000_000_000);
    }

    function test_convertDOT2TDOT_withoutHomaMint() public {
        dot.transfer(address(staking), staking.HOMA_MINT_THRESHOLD() * 2 - 2);
        assertEq(dot.balanceOf(address(staking)), staking.HOMA_MINT_THRESHOLD() * 2 - 2);
        assertEq(tdot.balanceOf(address(staking)), 0);

        assertEq(staking.convertDOT2TDOT(staking.HOMA_MINT_THRESHOLD() * 2 - 2), staking.HOMA_MINT_THRESHOLD() * 2 - 2);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), staking.HOMA_MINT_THRESHOLD() * 2 - 2);
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
        assertEq(staking.convertLCDOT2TDOT(20_000_000 ether), 18_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(lcdot.balanceOf(address(staking)), 80_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 18_000_000 ether);
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

    function test_convertTDOT2WTDOT_works() public {
        tdot.transfer(address(staking), 100_000 ether);
        assertEq(wtdot.totalSupply(), 0);
        assertEq(wtdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(wtdot)), 0);
        assertEq(tdot.balanceOf(address(staking)), 100_000 ether);

        assertEq(staking.convertTDOT2WTDOT(20_000 ether), 20_000 ether);
        assertEq(wtdot.totalSupply(), 20_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 20_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 20_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 80_000 ether);

        tdot.transfer(address(wtdot), 5_000 ether);
        assertEq(wtdot.totalSupply(), 20_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 20_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 25_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 80_000 ether);

        assertEq(staking.convertTDOT2WTDOT(20_000 ether), 16_000 ether);
        assertEq(wtdot.totalSupply(), 36_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 36_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 45_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 60_000 ether);
    }

    function test_convertWTDOT2TDOT_works() public {
        tdot.transfer(address(staking), 100_000 ether);
        assertEq(staking.convertTDOT2WTDOT(100_000 ether), 100_000 ether);
        assertEq(wtdot.totalSupply(), 100_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 100_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 100_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);

        assertEq(staking.convertWTDOT2TDOT(20_000 ether), 20_000 ether);
        assertEq(wtdot.totalSupply(), 80_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 80_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 20_000 ether);

        tdot.transfer(address(wtdot), 25_000 ether);
        assertEq(wtdot.totalSupply(), 80_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 80_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 105_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 20_000 ether);

        assertEq(staking.convertWTDOT2TDOT(20_000 ether), 26_250 ether);
        assertEq(wtdot.totalSupply(), 60_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 60_000 ether);
        assertEq(tdot.balanceOf(address(wtdot)), 78_750 ether);
        assertEq(tdot.balanceOf(address(staking)), 46_250 ether);
    }

    function test_convertLSTPool_revertNotOwner() public {
        assertEq(staking.owner(), ADMIN);
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
    }

    function test_convertLSTPool_revertEmptyPool() public {
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        vm.expectRevert("pool is empty");
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
    }

    function test_convertLSTPool_revertDismatchShareType() public {
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
        vm.expectRevert("share token must be LcDOT");
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2WTDOT);
        vm.expectRevert("share token must be DOT");
        staking.convertLSTPool(1, UpgradeableStakingLST.ConvertType.DOT2LDOT);
        vm.expectRevert("share token must be DOT");
        staking.convertLSTPool(1, UpgradeableStakingLST.ConvertType.DOT2WTDOT);
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
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
        emit LSTPoolConverted(0, lcdot, ldot, 1_000_000 ether, 8_000_000 ether);
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 8e18);

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
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
        emit LSTPoolConverted(0, lcdot, ldot, 1_000_000 ether, 10_000_000 ether);
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.DOT2LDOT);
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
        emit LSTPoolConverted(0, dot, ldot, 1_000_000 ether, 8_000_000 ether);
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.DOT2LDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 8e18);

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.DOT2LDOT);
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2WTDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 900_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 9e17);
        vm.revertTo(snapId);

        // // simulate convert LCDOT pool to WTDOT pool, and liquidCrowdloan redeem token is LDOT
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
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, IERC20(address(wtdot)), 1_000_000 ether, 1_000_000 ether);
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2WTDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 1e18);
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
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, lcdot, IERC20(address(wtdot)), 1_000_000 ether, 1_010_000 ether);
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2WTDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 1_010_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 101e16);
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
        vm.stopPrank();

        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(0, dot, IERC20(address(wtdot)), 1_000_000 ether, 900_000 ether);
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.DOT2WTDOT);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 900_000 ether);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 9e17);

        // revert for already converted
        vm.prank(ADMIN);
        vm.expectRevert("already converted");
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.DOT2WTDOT);
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
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
        vm.expectRevert("unsupported convert");
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2WTDOT);
        vm.expectEmit(false, false, false, true);
        emit LSTPoolConverted(1, dot, IERC20(address(wtdot)), 100_000 ether, 90_000 ether);
        staking.convertLSTPool(1, UpgradeableStakingLST.ConvertType.DOT2WTDOT);
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

    function test_stake_stakeTDOTToWTDOTPool() public {
        tdot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtdot)));
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 0);

        // ALICE stake TDOT to WTDOT pool
        vm.startPrank(ALICE);
        tdot.approve(address(staking), 100_000 ether);
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

        // ALICE stake TDOT to WTDOT pool
        vm.startPrank(ALICE);
        tdot.approve(address(staking), 100_000 ether);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 0, 80_000 ether);
        staking.stake(0, 100_000 ether);
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.LCDOT2LDOT);
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

    function test_unstake_unstakeTDOTFromWTDOTPool() public {
        tdot.transfer(ALICE, 1_000_000 ether);

        // create pool
        vm.prank(ADMIN);
        staking.addPool(IERC20(address(wtdot)));
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 1_000_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 0);

        // ALICE stake TDOT to WTDOT pool
        vm.startPrank(ALICE);
        tdot.approve(address(staking), 1_000_000 ether);
        vm.expectEmit(true, false, false, true);
        emit Stake(ALICE, 0, 1_000_000 ether);
        staking.stake(0, 1_000_000 ether);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 1_000_000 ether);

        // ALICE unstake TDOT from WTDOT pool
        vm.prank(ALICE);
        vm.expectEmit(true, false, false, true);
        emit Unstake(ALICE, 0, 100_000 ether);
        staking.unstake(0, 100_000 ether);
        assertEq(staking.totalShares(0), 900_000 ether);
        assertEq(staking.shares(0, ALICE), 900_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 100_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 900_000 ether);

        // mock the hold TDOT increased of WrappedTDOT
        tdot.transfer(address(wtdot), 90_000 ether);
        assertEq(wtdot.withdrawRate(), 11e17);

        // ALICE unstake TDOT from WTDOT pool
        vm.prank(ALICE);
        vm.expectEmit(true, false, false, true);
        emit Unstake(ALICE, 0, 100_000 ether);
        staking.unstake(0, 100_000 ether);
        assertEq(staking.totalShares(0), 800_000 ether);
        assertEq(staking.shares(0, ALICE), 800_000 ether);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 210_000 ether);
        assertEq(wtdot.balanceOf(address(staking)), 800_000 ether);
    }

    function test_unstake_unstakeTDOTFromConvert2WTDOTPool() public {
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
        staking.convertLSTPool(0, UpgradeableStakingLST.ConvertType.DOT2WTDOT);
        assertEq(address(staking.convertInfos(0).convertedShareType), address(wtdot));
        assertEq(staking.convertInfos(0).convertedExchangeRate, 9e17);
        assertEq(staking.totalShares(0), 1_000_000 ether);
        assertEq(staking.shares(0, ALICE), 1_000_000 ether);
        assertEq(dot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(wtdot.balanceOf(address(staking)), 900_000 ether);
        assertEq(dot.balanceOf(address(ALICE)), 0);
        assertEq(tdot.balanceOf(address(ALICE)), 0);

        // ALICE stake TDOT from the WTDOT pool which converted from DOT pool
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
        assertEq(tdot.balanceOf(address(ALICE)), 90_000 ether);

        // mock the hold TDOT increased of WrappedTDOT
        tdot.transfer(address(wtdot), 81_000 ether);
        assertEq(wtdot.withdrawRate(), 11e17);

        // ALICE stake TDOT from the WTDOT pool which converted from DOT pool
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
        assertEq(tdot.balanceOf(address(ALICE)), 189_000 ether);
    }
}

contract UpgradeableStakingLSTInitializeTest is Test {
    UpgradeableStakingLST public staking;
    MockHoma public homa;
    MockStableAsset public stableAsset;
    MockLiquidCrowdloan public liquidCrowdloan;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;
    WrappedTDOT public wtdot;

    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        lcdot = IERC20(address(new MockToken("Acala LcDOT", "LcDOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether)));
        tdot = IERC20(address(new MockToken("Acala tDOT", "tDOT", 1_000_000_000 ether)));
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

        vm.prank(ADMIN);
        staking = new UpgradeableStakingLST();
    }

    function test_initialize_works() public {
        assertEq(staking.owner(), address(0));
        assertEq(staking.DOT(), address(0));
        assertEq(staking.LCDOT(), address(0));
        assertEq(staking.LDOT(), address(0));
        assertEq(staking.TDOT(), address(0));
        assertEq(staking.HOMA(), address(0));
        assertEq(staking.STABLE_ASSET(), address(0));
        assertEq(staking.LIQUID_CROWDLOAN(), address(0));
        assertEq(staking.WTDOT(), address(0));

        // check params
        vm.prank(ALICE);
        vm.expectRevert("LIQUID_CROWDLOAN address is zero");
        staking.initialize(
            address(dot),
            address(lcdot),
            address(ldot),
            address(tdot),
            address(homa),
            address(stableAsset),
            address(0),
            address(wtdot)
        );

        // check initialize() has override and it will not do initialization
        vm.prank(ALICE);
        staking.initialize();
        assertEq(staking.owner(), address(0));
        vm.prank(ADMIN);
        staking.initialize();
        assertEq(staking.owner(), address(0));

        // anyone can initialize staking contract
        vm.prank(ALICE);
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
        assertEq(staking.owner(), ALICE);
        assertEq(staking.DOT(), address(dot));
        assertEq(staking.LCDOT(), address(lcdot));
        assertEq(staking.LDOT(), address(ldot));
        assertEq(staking.TDOT(), address(tdot));
        assertEq(staking.HOMA(), address(homa));
        assertEq(staking.STABLE_ASSET(), address(stableAsset));
        assertEq(staking.LIQUID_CROWDLOAN(), address(liquidCrowdloan));
        assertEq(staking.WTDOT(), address(wtdot));

        // initialize cannot be called twice
        vm.prank(ADMIN);
        vm.expectRevert("Initializable: contract is already initialized");
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
}
