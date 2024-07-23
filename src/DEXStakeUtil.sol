// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@AcalaNetwork/predeploy-contracts/dex/IDEX.sol";
import "./IStaking.sol";

/// @title DEXStakeUtil Contract
/// @author Acala Developers
/// @notice Utilitity contract support batch these operation:
/// 1. swap by Acala DEX
/// 2. add liquidity to Acala DEX pool to get LP token
/// 3. stake LP toke to Euphrates pool
contract DEXStakeUtil {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The token address of Euphrates.
    IStakingTo public immutable euphrates;

    /// @notice The DEX predeploy contract address.
    IDEX public immutable dex;

    /// @notice Deploys DEXStakeUtil contract.
    /// @param euphratesAddr The contract address of Euphrates.
    /// @param dexAddr The contract address of DEX predeploy contract.
    constructor(address euphratesAddr, address dexAddr) {
        euphrates = IStakingTo(euphratesAddr);
        dex = IDEX(dexAddr);
    }

    /// @notice Add liquidity to DEX to get LP token and stake to Euphrates pool.
    /// @param tokenA The first token of trading pair.
    /// @param amountA The amount of `tokenA` to add liquidity pool.
    /// @param tokenB The second token of trading pair.
    /// @param amountB The amount of `tokenB` to add liquidity pool.
    /// @param minShareAmount The acceptable minimum amount of LP token.
    /// @param poolId The if of Euphrates pool.
    /// @return Returns (success).
    function addLiquidityAndStake(
        IERC20 tokenA,
        uint256 amountA,
        IERC20 tokenB,
        uint256 amountB,
        uint256 minShareAmount,
        uint256 poolId
    ) public returns (bool) {
        IERC20 shareToken = IERC20(dex.getLiquidityTokenAddress(address(tokenA), address(tokenB)));
        require(address(shareToken) != address(0), "DEXStakeUtil: invalid trading pair");
        require(euphrates.shareTypes(poolId) == shareToken, "DEXStakeUtil: invalid pool");

        require(amountA != 0 && amountB != 0, "DEXStakeUtil: invalid amount");

        // transfer assets from msg.sender
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        // add liquidity
        uint256 beforeShareAmount = shareToken.balanceOf(address(this));
        bool success = dex.addLiquidity(address(tokenA), address(tokenB), amountA, amountB, minShareAmount);
        require(success, "DEXStakeUtil: add liquidity failed");
        uint256 afterShareAmount = shareToken.balanceOf(address(this));
        uint256 shareAmount = afterShareAmount.sub(beforeShareAmount);
        require(shareAmount != 0, "DEXStakeUtil: zero lp token amount is not allowed");

        // refund remain assets to sender
        tokenA.safeTransfer(msg.sender, tokenA.balanceOf(address(this)));
        tokenB.safeTransfer(msg.sender, tokenB.balanceOf(address(this)));

        // stake lp token to Euphrates pool
        shareToken.safeApprove(address(euphrates), shareAmount);
        return euphrates.stakeTo(poolId, shareAmount, msg.sender);
    }

    /// @notice Swap token and add liquidity to DEX to get LP token and then stake to Euphrates pool.
    /// @param tokenA The first token of trading pair.
    /// @param amountA The amount of `tokenA` to add liquidity pool.
    /// @param tokenB The second token of trading pair.
    /// @param amountB The amount of `tokenB` to add liquidity pool.
    /// @param swapPath The swap path.
    /// @param swapAmount The amount of first token of swapPath that be used to swap.
    /// @param minShareAmount The acceptable minimum amount of LP token.
    /// @param poolId The if of Euphrates pool.
    /// @return Returns (success).
    function swapAndAddLiquidityAndStake(
        IERC20 tokenA,
        uint256 amountA,
        IERC20 tokenB,
        uint256 amountB,
        address[] calldata swapPath,
        uint256 swapAmount,
        uint256 minShareAmount,
        uint256 poolId
    ) public returns (bool) {
        IERC20 shareToken = IERC20(dex.getLiquidityTokenAddress(address(tokenA), address(tokenB)));
        require(address(shareToken) != address(0), "DEXStakeUtil: invalid trading pair");
        require(euphrates.shareTypes(poolId) == shareToken, "DEXStakeUtil: invalid pool");

        // transfer assets from msg.sender
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        // swap path check
        require(swapPath.length >= 2, "DEXStakeUtil: invalid swap path length");

        // swap
        if (swapPath[0] == address(tokenA)) {
            require(swapPath[swapPath.length - 1] == address(tokenB), "DEXStakeUtil: invalid swap path");
            require(swapAmount <= amountA && swapAmount != 0, "DEXStakeUtil: invalid swap amount");
            bool result = dex.swapWithExactSupply(swapPath, swapAmount, 0);
            require(result, "DEXStakeUtil: swap failed");
        } else if (swapPath[0] == address(tokenB)) {
            require(swapPath[swapPath.length - 1] == address(tokenA), "DEXStakeUtil: invalid swap path");
            require(swapAmount <= amountB && swapAmount != 0, "DEXStakeUtil: invalid swap amount");
            bool result = dex.swapWithExactSupply(swapPath, swapAmount, 0);
            require(result, "DEXStakeUtil: swap failed");
        } else {
            revert("DEXStakeUtil: invalid swap path");
        }

        // add liquidity
        uint256 beforeShareAmount = shareToken.balanceOf(address(this));
        bool success = dex.addLiquidity(
            address(tokenA),
            address(tokenB),
            tokenA.balanceOf(address(this)),
            tokenB.balanceOf(address(this)),
            minShareAmount
        );
        require(success, "DEXStakeUtil: add liquidity failed");
        uint256 afterShareAmount = shareToken.balanceOf(address(this));
        uint256 shareAmount = afterShareAmount.sub(beforeShareAmount);
        require(shareAmount != 0, "DEXStakeUtil: zero lp token amount is not allowed");

        // refund remain assets to sender
        tokenA.safeTransfer(msg.sender, tokenA.balanceOf(address(this)));
        tokenB.safeTransfer(msg.sender, tokenB.balanceOf(address(this)));

        // stake lp token to Euphrates pool
        shareToken.safeApprove(address(euphrates), shareAmount);
        return euphrates.stakeTo(poolId, shareAmount, msg.sender);
    }
}
