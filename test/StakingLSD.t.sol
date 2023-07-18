// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/StakingLSD.sol";
import "../src/IHoma.sol";
import "../src/ILiquidCrowdloan.sol";
import "../src/IStableAsset.sol";
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
        tdot = new ERC20PresetFixedSupply("tcDOT", "tDOT", 40_000_000, ALICE);

        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAsset(address(ldot), address(tdot));
        liquidCrowdloan = new MockLiquidCrowdloan(address(lcdot), address(dot));

        vm.startPrank(ALICE);
        ldot.transfer(address(homa), 80_000_000);
        dot.transfer(address(liquidCrowdloan), 40_000_000);
        tdot.transfer(address(stableAsset), 40_000_000);
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
}
