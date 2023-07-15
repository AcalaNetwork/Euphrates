// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/access/Ownable.sol";
import "@openzeppelin-contracts/security/Pausable.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./PoolOperationPausable.sol";
import "./Staking.sol";

contract StakingCommon is Ownable, Pausable, Staking, PoolOperationPausable {
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /* override functions in base contract, some modifier and visibility changes */

    function setPoolOperationPause(uint256 poolId, Operation operation, bool paused)
        public
        override
        onlyOwner
        whenNotPaused
    {
        super.setPoolOperationPause(poolId, operation, paused);
    }

    function addPool(IERC20 shareType) public override onlyOwner whenNotPaused {
        super.addPool(shareType);
    }

    function setRewardsDeductionRate(uint256 poolId, uint256 rate) public override onlyOwner whenNotPaused {
        super.setRewardsDeductionRate(poolId, rate);
    }

    function notifyRewardRule(uint256 poolId, IERC20 rewardType, uint256 rewardAmountAdd, uint256 rewardDuration)
        public
        override
        onlyOwner
        whenNotPaused
    {
        super.notifyRewardRule(poolId, rewardType, rewardAmountAdd, rewardDuration);
    }

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

    function claimRewards(uint256 poolId)
        public
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.ClaimRewards)
        returns (bool)
    {
        return super.claimRewards(poolId);
    }

    function exit(uint256 poolId) external override returns (bool) {
        unstake(poolId, shares(poolId, msg.sender));
        claimRewards(poolId);
        return true;
    }
}
