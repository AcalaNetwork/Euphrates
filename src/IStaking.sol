// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @title IStaking Interface
/// @author Acala Developers
/// @notice You can use this integrate Acala LST staking into your contract.
interface IStaking {
    /// @notice Claim reward from staking pool.
    /// @param sender The sender of the transaction.
    /// @param poolId The index of staking pool.
    /// @param rewardType The reward token address.
    /// @param amount The claimed reward amount.
    event ClaimReward(address indexed sender, uint256 poolId, IERC20 indexed rewardType, uint256 amount);

    /// @notice Unstake share from staking pool.
    /// @param sender The sender of the transaction.
    /// @param poolId The index of staking pool.
    /// @param amount The share amount of unstake.
    event Unstake(address indexed sender, uint256 poolId, uint256 amount);

    /// @notice Stake share into staking pool.
    /// @param sender The sender of the transaction.
    /// @param poolId The index of staking pool.
    /// @param amount The share amount of stake.
    event Stake(address indexed sender, uint256 poolId, uint256 amount);

    /// @notice Get the share token address of the `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns (shareToken). If pool hasn't been initialized, return address(0x0).
    function shareTypes(uint256 poolId) external view returns (IERC20);

    /// @notice Get the total share amount of the `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns (totalShare).
    function totalShares(uint256 poolId) external view returns (uint256);

    /// @notice Get the all reward token types of the `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns (rewardTypesArr). Return all rewarded token types in this pool.
    function rewardTypes(uint256 poolId) external view returns (IERC20[] memory);

    /// @notice Get the share amount of `who` at `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param who The address of staker.
    /// @return Returns (shareAmount).
    function shares(uint256 poolId, address who) external view returns (uint256);

    /// @notice Get `who`'s unclaimed reward amount of specific `rewardType` at `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param who The address of staker.
    /// @param rewardType The reward token.
    /// @return Returns (rewardAmount).
    function earned(uint256 poolId, address who, IERC20 rewardType) external view returns (uint256);

    /// @notice Stake share into staking pool.
    /// @param poolId The index of staking pool.
    /// @param amount The share amount to stake.
    /// @return Returns (success).
    function stake(uint256 poolId, uint256 amount) external returns (bool);

    /// @notice Withdraw share from staking pool.
    /// @param poolId The index of staking pool.
    /// @return Returns (success).
    function unstake(uint256 poolId, uint256 amount) external returns (bool);

    /// @notice Claim all rewards from staking pool.
    /// @param poolId The index of staking pool.
    /// @return Returns (success).
    function claimRewards(uint256 poolId) external returns (bool);

    /// @notice Unstake all staked share and claim all unclaimed rewards from staking pool.
    /// @param poolId The index of staking pool.
    /// @return Returns (success).
    function exit(uint256 poolId) external returns (bool);
}

/// @title IStakingTo Interface
/// @author Acala Developers
/// @notice You can use this integrate Acala LST staking into your contract.
interface IStakingTo is IStaking {
    /// @notice Stake share to other.
    /// @param poolId The index of staking pool.
    /// @param amount The share amount to stake.
    /// @param receiver The share receiver.
    /// @return Returns (success).
    function stakeTo(uint256 poolId, uint256 amount, address receiver) external returns (bool);
}
