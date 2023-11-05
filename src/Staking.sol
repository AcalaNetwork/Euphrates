// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "./IStaking.sol";

/// @title Staking Abstract Contract
/// @author Acala Developers
/// @notice Staking supports multiple reward tokens and rewards claim deduction pubnishment.
/// Deduction rewards will be distributed to all stakers in the pool.
/// @dev This contract does not define access control for functions, you should override these define
/// in the derived contract.
abstract contract Staking is IStaking {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The rule for `rewardType` token at `poolId` pool updated.
    /// @param poolId The index of staking pool.
    /// @param rewardType The reward token.
    /// @param rewardRate The amount of `rewardType` token will accumulate per second.
    /// @param endTime The end time of this reward rule.
    event RewardRuleUpdate(uint256 poolId, IERC20 rewardType, uint256 rewardRate, uint256 endTime);

    /// @notice New staking pool.
    /// @param poolId The index of staking pool.
    /// @param shareType The share token of this staking pool.
    event NewPool(uint256 poolId, IERC20 shareType);

    /// @notice The deduction rate for all `rewardType` rewards of `poolId` pool updated.
    /// @param poolId The index of staking pool.
    /// @param rate The deduction rate.
    event RewardsDeductionRateSet(uint256 poolId, uint256 rate);

    struct RewardRule {
        // Reward amount per second.
        uint256 rewardRate;
        // The end time for reward accumulation.
        uint256 endTime;
        // Accumulated reward rate, this is used to calculate the reward amount of each staker.
        // It mul 1e18 to avoid loss of precision.
        uint256 rewardRateAccumulated;
        // The last time of this rule accumulates reward.
        uint256 lastAccumulatedTime;
    }

    /// @notice The maximum number of reward types for a staking pool. When distribute and receiving rewards,
    /// all reward types of a pool will be iterated. Limit the number of reward types to avoid out of huge gas.
    uint256 public constant MAX_REWARD_TYPES = 3;

    /// @dev The index of staking pools.
    uint256 internal _poolIndex = 0;

    /// @dev The share token of staking pool.
    /// (poolId => shareType)
    mapping(uint256 => IERC20) internal _shareTypes;

    /// @dev The share token of staking pool.
    /// (poolId => shareType)
    mapping(uint256 => uint256) internal _totalShares;

    /// @dev The deduction rate for all rewards of pool. 1e18 is 100%
    /// (poolId => rate)
    mapping(uint256 => uint256) internal _rewardsDeductionRates;

    /// @dev The reward token types of pool.
    /// (poolId => rewardTypeArr[])
    mapping(uint256 => IERC20[]) internal _rewardTypes;

    /// @dev The reward rule for reward type of pool.
    /// (poolId => (rewardType => rule))
    mapping(uint256 => mapping(IERC20 => RewardRule)) internal _rewardRules;

    /// @dev The share record for stakers of pool.
    /// (poolId => (staker => shareAmount))
    mapping(uint256 => mapping(address => uint256)) internal _shares;

    /// @dev The unclaimed reward amount for stakers of pool.
    /// (poolId => (staker => (rewardType => rewardAmount)))
    mapping(uint256 => mapping(address => mapping(IERC20 => uint256))) internal _rewards;

    /// @dev The reward accumulation rate for stakers of pool, this is used to calculate the reward amount of each staker.
    /// (poolId => (staker => (rewardType => rewardAmount)))
    mapping(uint256 => mapping(address => mapping(IERC20 => uint256))) internal _paidAccumulatedRates;

    /// @notice Get the index of next pool. It's equal to the current count of pools.
    /// @return Returns the next pool index.
    function poolIndex() public view virtual returns (uint256) {
        return _poolIndex;
    }

    /// @notice Get the share token of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns share token.
    function shareTypes(uint256 poolId) public view virtual override returns (IERC20) {
        return _shareTypes[poolId];
    }

    /// @notice Get the total share amount of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns total share amount.
    function totalShares(uint256 poolId) public view virtual override returns (uint256) {
        return _totalShares[poolId];
    }

    /// @notice Get the rewards decution rate of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns deduction rate.
    function rewardsDeductionRates(uint256 poolId) public view virtual returns (uint256) {
        return _rewardsDeductionRates[poolId];
    }

    /// @notice Get the reward token types of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns reward token array.
    function rewardTypes(uint256 poolId) public view virtual override returns (IERC20[] memory) {
        return _rewardTypes[poolId];
    }

    /// @notice Get the reward rule for `rewardType` reward of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param rewardType The reward token.
    /// @return Returns reward rule.
    function rewardRules(uint256 poolId, IERC20 rewardType) public view virtual returns (RewardRule memory) {
        return _rewardRules[poolId][rewardType];
    }

    /// @notice Get the share amount of `who` of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param who The staker.
    /// @return Returns share amount.
    function shares(uint256 poolId, address who) public view virtual override returns (uint256) {
        return _shares[poolId][who];
    }

    /// @notice Get the unclaimed paid `rewardType` reward amount for `who` of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param who The staker.
    /// @param rewardType The reward token.
    /// @return Returns reward amount.
    function rewards(uint256 poolId, address who, IERC20 rewardType) public view virtual returns (uint256) {
        return _rewards[poolId][who][rewardType];
    }

    /// @notice Get the paid accumulated rate of `rewardType` for `who` of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param who The staker.
    /// @param rewardType The reward token.
    /// @return Returns rate.
    function paidAccumulatedRates(uint256 poolId, address who, IERC20 rewardType)
        public
        view
        virtual
        returns (uint256)
    {
        return _paidAccumulatedRates[poolId][who][rewardType];
    }

    /// @notice Get lastest time that can be used to accumulate rewards for `rewardType` reward of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param rewardType The reward token.
    /// @return Returns timestamp.
    /// @dev If rule has ended, return the end time. Otherwise return the block time.
    function lastTimeRewardApplicable(uint256 poolId, IERC20 rewardType) public view virtual returns (uint256) {
        uint256 endTime = rewardRules(poolId, rewardType).endTime;
        return block.timestamp < endTime ? block.timestamp : endTime;
    }

    /// @notice Get the exchange rate for share to `rewardType` reward token of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param rewardType The reward token.
    /// @return Returns rate.
    /// @dev The reward part is accumulated rate adds pending to accumulate rate, it's used to calculate reward. 1e18 is 100%.
    function rewardPerShare(uint256 poolId, IERC20 rewardType) public view virtual returns (uint256) {
        RewardRule memory rewardRule = rewardRules(poolId, rewardType);
        uint256 totalShare = totalShares(poolId);

        if (totalShare == 0) {
            return rewardRule.rewardRateAccumulated;
        }

        uint256 pendingRewardRate = lastTimeRewardApplicable(poolId, rewardType).sub(rewardRule.lastAccumulatedTime).mul(
            rewardRule.rewardRate
        ).mul(1e18).div(totalShare); // mul 10**18 to avoid loss of precision

        return rewardRule.rewardRateAccumulated.add(pendingRewardRate);
    }

    /// @inheritdoc IStaking
    function earned(uint256 poolId, address who, IERC20 rewardType) public view virtual override returns (uint256) {
        uint256 share = shares(poolId, who);
        uint256 reward = rewards(poolId, who, rewardType);
        uint256 paidAccumulatedRate = paidAccumulatedRates(poolId, who, rewardType);
        uint256 pendingReward = share.mul(rewardPerShare(poolId, rewardType).sub(paidAccumulatedRate)).div(1e18); // div 10**18 that was mul in rewardPerShare

        return reward.add(pendingReward);
    }

    /// @dev Modifier to accumulate rewards for `poolId` pool, and distribute new accumulate rewards
    /// to `account`. If `account` is zero address, just accumulate rewards for pool.
    modifier updateRewards(uint256 poolId, address account) {
        IERC20[] memory types = rewardTypes(poolId);

        for (uint256 i = 0; i < types.length; i++) {
            RewardRule storage rewardRule = _rewardRules[poolId][types[i]];
            rewardRule.rewardRateAccumulated = rewardPerShare(poolId, types[i]);
            rewardRule.lastAccumulatedTime = lastTimeRewardApplicable(poolId, types[i]);

            // if account is not zero address, need accumulate reward and distribute
            if (account != address(0)) {
                _rewards[poolId][account][types[i]] = earned(poolId, account, types[i]);
                _paidAccumulatedRates[poolId][account][types[i]] = rewardRule.rewardRateAccumulated;
            }
        }

        _;
    }

    /// @notice Initialize a staking pool for `shareType`.
    /// @param shareType The share token.
    /// @dev you should override this function to define access control in the derived contract.
    function addPool(IERC20 shareType) public virtual {
        require(address(shareType) != address(0), "share token is zero address");

        uint256 poolId = poolIndex();
        _shareTypes[poolId] = shareType;
        _poolIndex = poolId.add(1);

        emit NewPool(poolId, shareType);
    }

    /// @notice Set deduction `rate` of claim rewards for `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param rate The deduction rate. 1e18 is 100%
    /// @dev you should override this function to define access control in the derived contract.
    function setRewardsDeductionRate(uint256 poolId, uint256 rate) public virtual {
        require(address(shareTypes(poolId)) != address(0), "invalid pool");
        require(rate <= 1e18, "invalid rate");

        _rewardsDeductionRates[poolId] = rate;
        emit RewardsDeductionRateSet(poolId, rate);
    }

    /// @notice Update the reward rule of `rewardType` for `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param rewardType The reward token.
    /// @param rewardRate The reward amount per second.
    /// @param endTime The end time of fule.
    /// @dev you should override this function to define access control in the derived contract.
    function updateRewardRule(uint256 poolId, IERC20 rewardType, uint256 rewardRate, uint256 endTime)
        public
        virtual
        updateRewards(poolId, address(0))
    {
        require(address(rewardType) != address(0), "reward token is zero address");
        require(address(shareTypes(poolId)) != address(0), "pool must be existed");

        IERC20[] memory types = rewardTypes(poolId);
        bool isNew = true;
        for (uint256 i = 0; i < types.length; i++) {
            if (types[i] == rewardType) {
                isNew = false;
                break;
            }
        }

        // if is a new reward type, need add to rewardTypes
        if (isNew) {
            _rewardTypes[poolId].push(rewardType);
        }
        require(_rewardTypes[poolId].length <= MAX_REWARD_TYPES, "too many reward types");

        RewardRule storage rewardRule = _rewardRules[poolId][rewardType];

        // rewards has accumulated to lastTimeRewardApplicable at previous updateRewards, so reset lastAccumulatedTime to now
        rewardRule.lastAccumulatedTime = block.timestamp;

        uint256 remainerReward;
        // If there are already rewards that have not yet ended, calculate the remainerReward that have not yet been accumulated.
        if (rewardRule.endTime > rewardRule.lastAccumulatedTime) {
            remainerReward = rewardRule.endTime.sub(rewardRule.lastAccumulatedTime).mul(rewardRule.rewardRate);
        }

        // reset endTime and rewardRate.
        if (block.timestamp > endTime) {
            rewardRule.endTime = block.timestamp;
        } else {
            rewardRule.endTime = endTime;
        }
        rewardRule.rewardRate = rewardRate;

        // calculate the newReward amount for the updated rewardRule.
        uint256 newReward = rewardRule.endTime.sub(rewardRule.lastAccumulatedTime).mul(rewardRule.rewardRate);

        if (remainerReward < newReward) {
            // if remainerReward is less than newReward, need transfer the gap from msg.sender to contract.
            rewardType.safeTransferFrom(msg.sender, address(this), newReward.sub(remainerReward));
        } else if (remainerReward > newReward) {
            // if remainerReward is greater than newReward, return the surplus part to msg.sender.
            rewardType.safeTransfer(msg.sender, remainerReward.sub(newReward));
        }

        emit RewardRuleUpdate(poolId, rewardType, rewardRule.rewardRate, rewardRule.endTime);
    }

    /// @inheritdoc IStaking
    function stake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "cannot stake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");

        _totalShares[poolId] = _totalShares[poolId].add(amount);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].add(amount);

        shareType.safeTransferFrom(msg.sender, address(this), amount);

        emit Stake(msg.sender, poolId, amount);

        return true;
    }

    /// @inheritdoc IStaking
    function unstake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "cannot unstake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");
        require(shares(poolId, msg.sender) >= amount, "share not enough");

        _totalShares[poolId] = _totalShares[poolId].sub(amount);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].sub(amount);

        shareType.safeTransfer(msg.sender, amount);

        emit Unstake(msg.sender, poolId, amount);

        return true;
    }

    /// @inheritdoc IStaking
    function claimRewards(uint256 poolId) public virtual override updateRewards(poolId, msg.sender) returns (bool) {
        IERC20[] memory types = rewardTypes(poolId);
        uint256 deductionRate = rewardsDeductionRates(poolId);

        for (uint256 i = 0; i < types.length; ++i) {
            uint256 rewardAmount = rewards(poolId, msg.sender, types[i]);
            if (rewardAmount > 0) {
                _rewards[poolId][msg.sender][types[i]] = 0;

                uint256 deduction = rewardAmount.mul(deductionRate).div(1e18);
                uint256 remainingReward = rewardAmount.sub(deduction);

                if (deduction > 0) {
                    RewardRule storage rewardRule = _rewardRules[poolId][types[i]];
                    uint256 totalShare = totalShares(poolId);

                    if (totalShare != 0) {
                        // redistribute the deduction to all stakers
                        uint256 addedAccumulatedRate = deduction.mul(1e18).div(totalShare);
                        rewardRule.rewardRateAccumulated = rewardRule.rewardRateAccumulated.add(addedAccumulatedRate);
                    }
                }

                types[i].safeTransfer(msg.sender, remainingReward);
                emit ClaimReward(msg.sender, poolId, types[i], remainingReward);
            }
        }

        return true;
    }

    /// @inheritdoc IStaking
    function exit(uint256 poolId) external virtual override returns (bool) {
        unstake(poolId, shares(poolId, msg.sender));
        claimRewards(poolId);
        return true;
    }
}
