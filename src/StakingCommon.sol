// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/access/Ownable.sol";
import "@openzeppelin-contracts/security/Pausable.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./PoolOperationPausable.sol";
import "./Staking.sol";

/// @title StakingCommon Contract
/// @author Acala Developers
/// @notice You can use this contract as a base contract for staking.
/// @dev This contract derived Ownable, Pausable and PoolOperationPausable, and overrides some functions to add access control for these.
contract StakingCommon is Ownable, Pausable, Staking, PoolOperationPausable {
    /// @notice Puase the contract by Pausable.
    /// @dev Only the owner of Ownable can call this function.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpuase the contract by Pausable.
    /// @dev Only the owner of Ownable can call this function.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc PoolOperationPausable
    /// @dev Override the inherited function to define access control.
    function setPoolOperationPause(uint256 poolId, Operation operation, bool paused)
        public
        override
        onlyOwner
        whenNotPaused
    {
        super.setPoolOperationPause(poolId, operation, paused);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define access control.
    function addPool(IERC20 shareType) public override onlyOwner whenNotPaused {
        super.addPool(shareType);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define access control.
    function setRewardsDeductionRate(uint256 poolId, uint256 rate) public override onlyOwner whenNotPaused {
        super.setRewardsDeductionRate(poolId, rate);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define access control.
    function notifyRewardRule(uint256 poolId, IERC20 rewardType, uint256 rewardAmountAdd, uint256 rewardDuration)
        public
        override
        onlyOwner
        whenNotPaused
    {
        super.notifyRewardRule(poolId, rewardType, rewardAmountAdd, rewardDuration);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define access control.
    function stake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        returns (bool)
    {
        return super.stake(poolId, amount);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define access control.
    function unstake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Unstake)
        returns (bool)
    {
        return super.unstake(poolId, amount);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define access control.
    function claimRewards(uint256 poolId)
        public
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.ClaimRewards)
        returns (bool)
    {
        return super.claimRewards(poolId);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define access control.
    function exit(uint256 poolId) external override returns (bool) {
        unstake(poolId, shares(poolId, msg.sender));
        claimRewards(poolId);
        return true;
    }
}
