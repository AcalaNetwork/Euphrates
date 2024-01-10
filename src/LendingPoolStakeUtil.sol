// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@starlay-protocol/interfaces/ILendingPool.sol";
import "./IStaking.sol";

/// @title LendingPoolStakeUtil Contract
/// @author Acala Developers
/// @notice Utilitity contract support batch these operation:
/// 1. deposit token to LendingPool to get lToken
/// 2. stake lToken to Euphrates pool
contract LendingPoolStakeUtil {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The token address of Euphrates.
    IStakingTo public immutable euphrates;

    /// @notice The Starlay LendingPool contract address.
    ILendingPool public immutable lendingPool;

    /// @notice Deploys LendingPoolStakeUtil contract.
    /// @param euphratesAddr The contract address of Euphrates.
    /// @param lendingPoolAddr The contract address of Starlay LendingPool.
    constructor(address euphratesAddr, address lendingPoolAddr) {
        euphrates = IStakingTo(euphratesAddr);
        lendingPool = ILendingPool(lendingPoolAddr);
    }

    /// @notice Deposit token to LendingPool and stake lToken to Euphrates pool.
    /// @param asset The token to deposit LendingPool.
    /// @param amount The amount of token to deposit.
    /// @param poolId The id of Euphrates pool.
    /// @return Returns (success).
    function depositAndStake(IERC20 asset, uint256 amount, uint256 poolId) public returns (bool) {
        require(amount != 0, "LendingPoolStakeUtil: zero amount is not allowed");
        address lTokenAddress = lendingPool.getReserveData(address(asset)).lTokenAddress;
        require(
            address(euphrates.shareTypes(poolId)) == lTokenAddress,
            "LendingPoolStakeUtil: the pool share token of Euphrates is not matched the LendingPool lToken for asset"
        );

        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.safeApprove(address(lendingPool), amount);

        uint256 beforeLTokenAmount = IERC20(lTokenAddress).balanceOf(address(this));
        lendingPool.deposit(address(asset), amount, address(this), 0);
        uint256 afterLTokenAmount = IERC20(lTokenAddress).balanceOf(address(this));
        uint256 lTokenAmount = afterLTokenAmount.sub(beforeLTokenAmount);

        // stake lToken to Euphrates pool
        IERC20(lTokenAddress).safeApprove(address(euphrates), lTokenAmount);
        return euphrates.stakeTo(poolId, lTokenAmount, msg.sender);
    }
}
