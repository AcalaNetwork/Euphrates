// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./PoolOperationPausable.sol";
import "./Staking.sol";

/// @title UpgradeableStakingCommon Contract
/// @author Acala Developers
/// @notice You can use this contract as a base contract for staking.
/// @dev This contract derived OwnableUpgradeable, PausableUpgradeable and PoolOperationPausable,
/// and overrides some functions to add access control for these.
/// This version conforms to the specification for upgradeable contracts.
contract UpgradeableStakingCommon is
    OwnableUpgradeable,
    PausableUpgradeable,
    Staking,
    PoolOperationPausable,
    ReentrancyGuardUpgradeable
{
    /// @notice The initialize function.
    /// @dev proxy contract will call this when firstly fetch this contract as the implementation contract.
    function initialize() public virtual initializer {
        __Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /// @notice Puase the contract by Pausable.
    /// @dev Define the `onlyOwner` access.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpuase the contract by Pausable.
    /// @dev Define the `onlyOwner` access.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc PoolOperationPausable
    /// @dev Override the inherited function to define `onlyOwner` and `whenNotPaused` access.
    function setPoolOperationPause(uint256 poolId, Operation operation, bool paused)
        public
        override
        onlyOwner
        whenNotPaused
    {
        super.setPoolOperationPause(poolId, operation, paused);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define `onlyOwner` and `whenNotPaused` access.
    function addPool(IERC20 shareType) public override onlyOwner whenNotPaused {
        super.addPool(shareType);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define `onlyOwner` and `whenNotPaused` access.
    function setRewardsDeductionRate(uint256 poolId, uint256 rate) public override onlyOwner whenNotPaused {
        super.setRewardsDeductionRate(poolId, rate);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define `onlyOwner` and `whenNotPaused` access.
    function updateRewardRule(uint256 poolId, IERC20 rewardType, uint256 rewardRate, uint256 endTime)
        public
        override
        onlyOwner
        whenNotPaused
    {
        super.updateRewardRule(poolId, rewardType, rewardRate, endTime);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define `whenNotPaused` and `poolOperationNotPaused(poolId, Operation.Stake)` access.
    function stake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        nonReentrant
        returns (bool)
    {
        return super.stake(poolId, amount);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define `whenNotPaused` and `poolOperationNotPaused(poolId, Operation.Unstake)`.
    function unstake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Unstake)
        nonReentrant
        returns (bool)
    {
        return super.unstake(poolId, amount);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define `whenNotPaused` and `poolOperationNotPaused(poolId, Operation.ClaimRewards)`.
    function claimRewards(uint256 poolId)
        public
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.ClaimRewards)
        nonReentrant
        returns (bool)
    {
        return super.claimRewards(poolId);
    }

    /// @inheritdoc Staking
    /// @dev Override the inherited function to define access.
    function exit(uint256 poolId) external override returns (bool) {
        unstake(poolId, shares(poolId, msg.sender));
        claimRewards(poolId);
        return true;
    }
}
