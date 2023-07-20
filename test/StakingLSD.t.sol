// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/StakingLSD.sol";
import "../src/IHoma.sol";
import "../src/ILiquidCrowdloan.sol";
import "../src/IStableAsset.sol";
import "../src/UpgradeableStakingLSD.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "@openzeppelin-contracts/utils/math/SafeMath.sol";

error Unimplement();
error InvalidPool();
error InvalidAmountsLength();
error InvalidAmounts();

contract MockLiquidCrowdloan is ILiquidCrowdloan, Test {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable LCDOT;
    address public immutable DOT;

    constructor(address lcdot, address dot) {
        LCDOT = lcdot;
        DOT = dot;
    }

    function redeem(uint256 amount) external returns (bool) {
        // NOTE: Acala EVM+ precompile burn LcDOT on runtime,
        // here we use cheatcode to simulate transfer LcDOT to this contract.
        vm.prank(msg.sender);
        IERC20(LCDOT).safeTransfer(address(this), amount);

        IERC20(DOT).safeTransfer(msg.sender, amount);
    }
}

contract MockStableAsset is IStableAsset, Test {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable DOT;
    address public immutable TDOT;

    constructor(address dot, address tdot) {
        DOT = dot;
        TDOT = tdot;
    }

    function getStableAssetPoolTokens(uint32 poolId) external view returns (bool, address[] memory) {
        revert Unimplement();
    }

    function getStableAssetPoolTotalSupply(uint32 poolId) external view returns (bool, uint256) {
        revert Unimplement();
    }

    function getStableAssetPoolPrecision(uint32 poolId) external view returns (bool, uint256) {
        revert Unimplement();
    }

    function getStableAssetPoolMintFee(uint32 poolId) external view returns (bool, uint256) {
        revert Unimplement();
    }

    function getStableAssetPoolSwapFee(uint32 poolId) external view returns (bool, uint256) {
        revert Unimplement();
    }

    function getStableAssetPoolRedeemFee(uint32 poolId) external view returns (bool, uint256) {
        revert Unimplement();
    }

    function stableAssetSwap(uint32 poolId, uint32 i, uint32 j, uint256 dx, uint256 minDY, uint32 assetLength)
        external
        returns (bool)
    {
        revert Unimplement();
    }

    function stableAssetMint(uint32 poolId, uint256[] calldata amounts, uint256 minMintAmount)
        external
        returns (bool)
    {
        if (poolId != 0) {
            revert InvalidPool();
        }
        if (amounts.length != 2) {
            revert InvalidAmountsLength();
        }
        if (amounts[1] != 0) {
            revert InvalidAmounts();
        }
        if (amounts[0] < minMintAmount) {
            revert InvalidAmounts();
        }

        uint256 dotAmount = amounts[0];

        // NOTE: Acala EVM+ precompile transfer system ERC20 on runtime,
        // here we use cheatcode to simulate transfer DOT to this contract.
        vm.prank(msg.sender);
        IERC20(DOT).safeTransfer(address(this), dotAmount);

        // mint tDOT at 1:1
        uint256 tdotAmount = dotAmount;
        IERC20(TDOT).safeTransfer(msg.sender, tdotAmount);

        return true;
    }

    function stableAssetRedeem(uint32 poolId, uint256 redeemAmount, uint256[] calldata amounts)
        external
        returns (bool)
    {
        revert Unimplement();
    }

    function stableAssetRedeemSingle(
        uint32 poolId,
        uint256 redeemAmount,
        uint32 i,
        uint256 minRedeemAmount,
        uint32 assetLength
    ) external returns (bool) {
        revert Unimplement();
    }

    function stableAssetRedeemMulti(uint32 poolId, uint256[] calldata amounts, uint256 maxRedeemAmount)
        external
        returns (bool)
    {
        revert Unimplement();
    }
}

contract MockHoma is IHoma, Test {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable STAKING_TOKEN;
    address public immutable LIDUID_TOKEN;

    constructor(address stakingToken, address liquidToken) {
        STAKING_TOKEN = stakingToken;
        LIDUID_TOKEN = liquidToken;
    }

    function mint(uint256 mintAmount) external returns (bool) {
        // NOTE: Acala EVM+ precompile transfer system ERC20 on runtime,
        // here we use cheatcode to simulate transfer DOT to this contract.
        vm.prank(msg.sender);
        IERC20(STAKING_TOKEN).safeTransfer(address(this), mintAmount);

        uint256 liquidAmount = mintAmount.mul(1e18).div(getExchangeRate());
        IERC20(LIDUID_TOKEN).safeTransfer(msg.sender, liquidAmount);
        emit Minted(msg.sender, mintAmount);
    }

    function requestRedeem(uint256 redeemAmount, bool fastMatch) external returns (bool) {
        revert Unimplement();
    }

    function getExchangeRate() public view returns (uint256) {
        return 1e18 / 8;
    }

    function getEstimatedRewardRate() external view returns (uint256) {
        revert Unimplement();
    }

    function getCommissionRate() external view returns (uint256) {
        revert Unimplement();
    }

    function getFastMatchFee() external view returns (uint256) {
        revert Unimplement();
    }
}

contract StakingLSDTest is Test {
    event LSDPoolConverted(uint256 poolId, IERC20 beforeShareType, IERC20 afterShareType, uint256 exchangeRate);
    event Unstake(address indexed account, uint256 poolId, uint256 amount);
    event Stake(address indexed account, uint256 poolId, uint256 amount);
    event ClaimReward(address indexed account, uint256 poolId, IERC20 indexed rewardType, uint256 amount);

    StakingLSD public staking;
    IHoma public homa;
    IStableAsset public stableAsset;
    ILiquidCrowdloan public liquidCrowdloan;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);
    address public BOB = address(0x3333);

    function setUp() public {
        dot = new ERC20PresetFixedSupply("DOT", "DOT", 100_000_000, ALICE);
        lcdot = new ERC20PresetFixedSupply("LcDOT", "LcDOT", 50_000_000, ALICE);
        ldot = new ERC20PresetFixedSupply("LDOT", "LDOT", 80_000_000, ALICE);
        tdot = new ERC20PresetFixedSupply("tDOT", "tDOT", 40_000_000, ALICE);

        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAsset(address(dot), address(tdot));
        liquidCrowdloan = new MockLiquidCrowdloan(address(lcdot), address(dot));

        vm.startPrank(ALICE);
        ldot.transfer(address(homa), 80_000_000);
        dot.transfer(address(liquidCrowdloan), 40_000_000);
        tdot.transfer(address(stableAsset), 40_000_000);
        vm.stopPrank();

        vm.prank(ADMIN);
        staking = new StakingLSD(
            address(dot),
            address(lcdot),
            address(ldot),
            address(tdot),
            address(homa),
            address(stableAsset),
            address(liquidCrowdloan)
        );
    }

    function test_MockHoma_works() public {
        assertEq(dot.balanceOf(ALICE), 60_000_000);
        assertEq(dot.balanceOf(address(homa)), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(homa)), 80_000_000);

        vm.prank(ALICE);
        homa.mint(1_000_000);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(homa)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 8_000_000);
        assertEq(ldot.balanceOf(address(homa)), 72_000_000);
    }

    function test_MockStableAsset_works() public {
        assertEq(dot.balanceOf(ALICE), 60_000_000);
        assertEq(dot.balanceOf(address(stableAsset)), 0);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(address(stableAsset)), 40_000_000);

        vm.prank(ALICE);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000;
        amounts[1] = 0;
        stableAsset.stableAssetMint(0, amounts, 0);

        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(stableAsset)), 1_000_000);
        assertEq(tdot.balanceOf(ALICE), 1_000_000);
        assertEq(tdot.balanceOf(address(stableAsset)), 39_000_000);
    }

    function test_MockLiquidCrowdloan_works() public {
        assertEq(lcdot.balanceOf(ALICE), 50_000_000);
        assertEq(lcdot.balanceOf(address(liquidCrowdloan)), 0);
        assertEq(dot.balanceOf(ALICE), 60_000_000);
        assertEq(dot.balanceOf(address(liquidCrowdloan)), 40_000_000);

        vm.prank(ALICE);
        liquidCrowdloan.redeem(8_000_000);

        assertEq(lcdot.balanceOf(ALICE), 42_000_000);
        assertEq(lcdot.balanceOf(address(liquidCrowdloan)), 8_000_000);
        assertEq(dot.balanceOf(ALICE), 68_000_000);
        assertEq(dot.balanceOf(address(liquidCrowdloan)), 32_000_000);
    }

    function test_convertLSDPool_works() public {
        // caller is not owner
        assertEq(staking.owner(), ADMIN);
        vm.prank(BOB);
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

        // ALICE add share to pool#1
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 1_000_000);
        staking.stake(1, 1_000_000);
        vm.stopPrank();
        assertEq(staking.totalShares(1), 1_000_000);
        assertEq(staking.shares(1, ALICE), 1_000_000);
        assertEq(lcdot.balanceOf(ALICE), 49_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(0));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 0);

        // convert pool#1 to LDOT by homa
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(1, lcdot, ldot, 8e18);
        staking.convertLSDPool(1, StakingLSD.ConvertType.Lcdot2Ldot);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000);
        assertEq(address(staking.convertInfos(1).convertedShareType), address(ldot));
        assertEq(staking.convertInfos(1).convertedExchangeRate, 8e18);

        assertEq(staking.totalShares(1), 1_000_000);
        assertEq(staking.shares(1, ALICE), 1_000_000);
        assertEq(lcdot.balanceOf(ALICE), 49_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(staking)), 8_000_000);

        // ALICE unstake from pool#1
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit Unstake(ALICE, 1, 250_000);
        staking.unstake(1, 250_000);
        assertEq(staking.totalShares(1), 750_000);
        assertEq(staking.shares(1, ALICE), 750_000);
        assertEq(lcdot.balanceOf(ALICE), 49_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(ALICE), 2_000_000);
        assertEq(ldot.balanceOf(address(staking)), 6_000_000);

        // ALICE stake extra to pool#1, now the actual share token is LDOT
        vm.startPrank(ALICE);
        ldot.approve(address(staking), 1_000_000);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 1, 125_000);
        staking.stake(1, 125_000);
        vm.stopPrank();
        assertEq(staking.totalShares(1), 875_000);
        assertEq(staking.shares(1, ALICE), 875_000);
        assertEq(lcdot.balanceOf(ALICE), 49_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(ldot.balanceOf(ALICE), 1_000_000);
        assertEq(ldot.balanceOf(address(staking)), 7_000_000);

        // ALICE add share to pool#2
        vm.startPrank(ALICE);
        lcdot.approve(address(staking), 1_000_000);
        staking.stake(2, 1_000_000);
        vm.stopPrank();
        assertEq(staking.totalShares(2), 1_000_000);
        assertEq(staking.shares(2, ALICE), 1_000_000);
        assertEq(lcdot.balanceOf(ALICE), 48_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 1_000_000);
        assertEq(tdot.balanceOf(ALICE), 0);
        assertEq(tdot.balanceOf(address(staking)), 0);
        assertEq(address(staking.convertInfos(2).convertedShareType), address(0));
        assertEq(staking.convertInfos(2).convertedExchangeRate, 0);

        // convert pool#2 to TDOT by StableAsset
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(2, lcdot, tdot, 1e18);
        staking.convertLSDPool(2, StakingLSD.ConvertType.Lcdot2Tdot);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(address(staking)), 1_000_000);
        assertEq(address(staking.convertInfos(2).convertedShareType), address(tdot));
        assertEq(staking.convertInfos(2).convertedExchangeRate, 1e18);

        // ALICE unstake from pool#2
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit Unstake(ALICE, 2, 200_000);
        staking.unstake(2, 200_000);
        assertEq(staking.totalShares(2), 800_000);
        assertEq(staking.shares(2, ALICE), 800_000);
        assertEq(lcdot.balanceOf(ALICE), 48_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(ALICE), 200_000);
        assertEq(tdot.balanceOf(address(staking)), 800_000);

        // ALICE stake extra to pool#2, now the actual share token is TDOT
        vm.startPrank(ALICE);
        tdot.approve(address(staking), 100_000);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 2, 100_000);
        staking.stake(2, 100_000);
        vm.stopPrank();
        assertEq(staking.totalShares(2), 900_000);
        assertEq(staking.shares(2, ALICE), 900_000);
        assertEq(lcdot.balanceOf(ALICE), 48_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(tdot.balanceOf(ALICE), 100_000);
        assertEq(tdot.balanceOf(address(staking)), 900_000);
    }

    function test_stake_RevertZeroAmount() public {
        vm.expectRevert("cannot stake 0");
        staking.stake(0, 0);
    }

    function test_stake_RevertInvalidPool() public {
        vm.expectRevert("invalid pool");
        staking.stake(0, 100);
    }

    function test_stake_works() public {
        vm.warp(1_689_500_000);

        // create pool
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        staking.notifyRewardRule(0, dot, 1_000_000, 2_000);
        vm.stopPrank();

        vm.startPrank(ALICE);
        dot.transfer(address(staking), 1_000_000);
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(lcdot.balanceOf(ALICE), 50_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE add share to pool#0
        lcdot.approve(address(staking), 1_000_000);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 200_000);
        staking.stake(0, 200_000);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 200_000);
        assertEq(staking.shares(0, ALICE), 200_000);
        assertEq(lcdot.balanceOf(ALICE), 49_800_000);
        assertEq(lcdot.balanceOf(address(staking)), 200_000);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // convert pool#0 to LDOT by homa
        vm.warp(1_689_501_000);
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, lcdot, ldot, 8e18);
        staking.convertLSDPool(0, StakingLSD.ConvertType.Lcdot2Ldot);

        assertEq(staking.totalShares(0), 200_000);
        assertEq(staking.shares(0, ALICE), 200_000);
        assertEq(lcdot.balanceOf(ALICE), 49_800_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(staking)), 1_600_000);
        assertEq(staking.rewards(0, ALICE, dot), 0);
        assertEq(staking.earned(0, ALICE, dot), 500_000);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        vm.prank(address(homa));
        ldot.transfer(ALICE, 4_000_000);
        assertEq(ldot.balanceOf(ALICE), 4_000_000);

        // ALICE stake extra share to pool#0, not actual share token is LDOT
        vm.startPrank(ALICE);
        ldot.approve(address(staking), 4_000_000);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 500_000);
        staking.stake(0, 500_000);
        vm.stopPrank();

        assertEq(staking.totalShares(0), 700_000);
        assertEq(staking.shares(0, ALICE), 700_000);
        assertEq(lcdot.balanceOf(ALICE), 49_800_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(staking)), 5_600_000);
        assertEq(staking.rewards(0, ALICE, dot), 500_000);
        assertEq(staking.earned(0, ALICE, dot), 500_000);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardPerShare(0, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 * 1000 * 1e18 / 200_000);
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

        // create pool
        vm.startPrank(ADMIN);
        staking.addPool(lcdot);
        staking.notifyRewardRule(0, dot, 1_000_000, 2_000);
        vm.stopPrank();

        vm.startPrank(ALICE);
        dot.transfer(address(staking), 1_000_000);
        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(lcdot.balanceOf(ALICE), 50_000_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE add share to pool#0
        lcdot.approve(address(staking), 1_000_000);
        vm.expectEmit(false, false, false, true);
        emit Stake(ALICE, 0, 200_000);
        staking.stake(0, 200_000);
        vm.stopPrank();
        assertEq(staking.totalShares(0), 200_000);
        assertEq(staking.shares(0, ALICE), 200_000);
        assertEq(lcdot.balanceOf(ALICE), 49_800_000);
        assertEq(lcdot.balanceOf(address(staking)), 200_000);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 0);
        assertEq(staking.rewardPerShare(0, dot), 0);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 0);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_500_000);

        // ALICE unstake some share
        vm.warp(1_689_501_000);
        vm.prank(ALICE);
        emit Unstake(ALICE, 0, 50_000);
        staking.unstake(0, 50_000);
        assertEq(staking.totalShares(0), 150_000);
        assertEq(staking.shares(0, ALICE), 150_000);
        assertEq(lcdot.balanceOf(ALICE), 49_850_000);
        assertEq(lcdot.balanceOf(address(staking)), 150_000);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.rewards(0, ALICE, dot), 500_000);
        assertEq(staking.earned(0, ALICE, dot), 500_000);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardPerShare(0, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // convert pool#0 to LDOT by homa
        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit LSDPoolConverted(0, lcdot, ldot, 8e18);
        staking.convertLSDPool(0, StakingLSD.ConvertType.Lcdot2Ldot);

        assertEq(staking.totalShares(0), 150_000);
        assertEq(staking.shares(0, ALICE), 150_000);
        assertEq(lcdot.balanceOf(ALICE), 49_850_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 0);
        assertEq(ldot.balanceOf(address(staking)), 1_200_000);
        assertEq(staking.rewards(0, ALICE, dot), 500_000);
        assertEq(staking.earned(0, ALICE, dot), 500_000);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardPerShare(0, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // ALICE unstake all share
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit Unstake(ALICE, 0, 100_000);
        staking.unstake(0, 100_000);

        assertEq(staking.totalShares(0), 50_000);
        assertEq(staking.shares(0, ALICE), 50_000);
        assertEq(lcdot.balanceOf(ALICE), 49_850_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(ALICE), 59_000_000);
        assertEq(dot.balanceOf(address(staking)), 1_000_000);
        assertEq(ldot.balanceOf(ALICE), 800_000);
        assertEq(ldot.balanceOf(address(staking)), 400_000);
        assertEq(staking.rewards(0, ALICE, dot), 500_000);
        assertEq(staking.earned(0, ALICE, dot), 500_000);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardPerShare(0, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);

        // ALICE exit
        vm.prank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit Unstake(ALICE, 0, 50_000);
        emit ClaimReward(ALICE, 0, dot, 500_000);
        staking.exit(0);

        assertEq(staking.totalShares(0), 0);
        assertEq(staking.shares(0, ALICE), 0);
        assertEq(lcdot.balanceOf(ALICE), 49_850_000);
        assertEq(lcdot.balanceOf(address(staking)), 0);
        assertEq(dot.balanceOf(ALICE), 59_500_000);
        assertEq(dot.balanceOf(address(staking)), 500_000);
        assertEq(ldot.balanceOf(ALICE), 1_200_000);
        assertEq(ldot.balanceOf(address(staking)), 0);
        assertEq(staking.rewards(0, ALICE, dot), 0);
        assertEq(staking.earned(0, ALICE, dot), 0);
        assertEq(staking.paidAccumulatedRates(0, ALICE, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardPerShare(0, dot), 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).rewardRate, 500);
        assertEq(staking.rewardRules(0, dot).endTime, 1_689_502_000);
        assertEq(staking.rewardRules(0, dot).rewardRateAccumulated, 500 * 1000 * 1e18 / 200_000);
        assertEq(staking.rewardRules(0, dot).lastAccumulatedTime, 1_689_501_000);
    }
}

contract UpgradeableStakingLSDTest is Test {
    UpgradeableStakingLSD public staking;
    IHoma public homa;
    IStableAsset public stableAsset;
    ILiquidCrowdloan public liquidCrowdloan;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;
    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);

    function setUp() public {
        dot = new ERC20PresetFixedSupply("DOT", "DOT", 100_000_000, ALICE);
        lcdot = new ERC20PresetFixedSupply("LcDOT", "LcDOT", 50_000_000, ALICE);
        ldot = new ERC20PresetFixedSupply("LDOT", "LDOT", 80_000_000, ALICE);
        tdot = new ERC20PresetFixedSupply("tDOT", "tDOT", 40_000_000, ALICE);

        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAsset(address(dot), address(tdot));
        liquidCrowdloan = new MockLiquidCrowdloan(address(lcdot), address(dot));

        vm.startPrank(ALICE);
        ldot.transfer(address(homa), 80_000_000);
        dot.transfer(address(liquidCrowdloan), 40_000_000);
        tdot.transfer(address(stableAsset), 40_000_000);
        vm.stopPrank();

        vm.prank(ADMIN);
        staking = new UpgradeableStakingLSD();
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

        // check params
        vm.prank(ALICE);
        vm.expectRevert("LIQUID_CROWDLOAN address is zero");
        staking.initialize(
            address(dot), address(lcdot), address(ldot), address(tdot), address(homa), address(stableAsset), address(0)
        );

        // anyone can initialize staking contract
        vm.prank(ALICE);
        staking.initialize(
            address(dot),
            address(lcdot),
            address(ldot),
            address(tdot),
            address(homa),
            address(stableAsset),
            address(liquidCrowdloan)
        );
        assertEq(staking.owner(), ALICE);
        assertEq(staking.DOT(), address(dot));
        assertEq(staking.LCDOT(), address(lcdot));
        assertEq(staking.LDOT(), address(ldot));
        assertEq(staking.TDOT(), address(tdot));
        assertEq(staking.HOMA(), address(homa));
        assertEq(staking.STABLE_ASSET(), address(stableAsset));
        assertEq(staking.LIQUID_CROWDLOAN(), address(liquidCrowdloan));

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
            address(liquidCrowdloan)
        );
    }
}
