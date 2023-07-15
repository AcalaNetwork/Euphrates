// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "./IStaking.sol";

abstract contract Staking is IStaking {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event RewardRuleUpdated(uint256 poolId, IERC20 rewardType, uint256 rewardRate, uint256 endTime);
    event NewPool(uint256 poolId, IERC20 shareType);
    event RewardsDeductionRateSet(uint256 poolId, uint256 rate);

    struct RewardRule {
        uint256 rewardRate; // reward amount per second
        uint256 endTime;
        uint256 rewardRateAccumulated; // already mul 1e18 to avoid loss of precision
        uint256 lastAccumulatedTime;
    }

    uint256 public constant MAX_REWARD_TYPES = 3;

    uint256 internal _poolIndex = 0;
    mapping(uint256 => IERC20) internal _shareTypes;
    mapping(uint256 => uint256) internal _totalShares;
    mapping(uint256 => uint256) internal _rewardsDeductionRates; // 1e18 is 100%
    mapping(uint256 => IERC20[]) internal _rewardTypes;

    mapping(uint256 => mapping(IERC20 => RewardRule)) internal _rewardRules;
    mapping(uint256 => mapping(address => uint256)) internal _shares;
    mapping(uint256 => mapping(address => mapping(IERC20 => uint256))) internal _rewards;
    mapping(uint256 => mapping(address => mapping(IERC20 => uint256))) internal _paidAccumulatedRates;

    function poolIndex() public view virtual returns (uint256) {
        return _poolIndex;
    }

    function shareTypes(uint256 poolId) public view virtual override returns (IERC20) {
        return _shareTypes[poolId];
    }

    function totalShares(uint256 poolId) public view virtual override returns (uint256) {
        return _totalShares[poolId];
    }

    function rewardsDeductionRates(uint256 poolId) public view virtual returns (uint256) {
        return _rewardsDeductionRates[poolId];
    }

    function rewardTypes(uint256 poolId) public view virtual override returns (IERC20[] memory) {
        return _rewardTypes[poolId];
    }

    function rewardRules(uint256 poolId, IERC20 rewardType) public view virtual returns (RewardRule memory) {
        return _rewardRules[poolId][rewardType];
    }

    function shares(uint256 poolId, address account) public view virtual override returns (uint256) {
        return _shares[poolId][account];
    }

    function rewards(uint256 poolId, address account, IERC20 rewardType) public view virtual returns (uint256) {
        return _rewards[poolId][account][rewardType];
    }

    function paidAccumulatedRates(uint256 poolId, address account, IERC20 rewardType)
        public
        view
        virtual
        returns (uint256)
    {
        return _paidAccumulatedRates[poolId][account][rewardType];
    }

    function lastTimeRewardApplicable(uint256 poolId, IERC20 rewardType) public view virtual returns (uint256) {
        uint256 endTime = rewardRules(poolId, rewardType).endTime;
        return block.timestamp < endTime ? block.timestamp : endTime;
    }

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

    function earned(uint256 poolId, address account, IERC20 rewardType)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 share = shares(poolId, account);
        uint256 reward = rewards(poolId, account, rewardType);
        uint256 paidAccumulatedRate = paidAccumulatedRates(poolId, account, rewardType);
        uint256 pendingReward = share.mul(rewardPerShare(poolId, rewardType).sub(paidAccumulatedRate)).div(1e18); // div 10**18 that was mul in rewardPerShare

        return reward.add(pendingReward);
    }

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

    function addPool(IERC20 shareType) public virtual {
        require(address(shareType) != address(0), "0 address not allowed");

        uint256 poolId = poolIndex();
        _shareTypes[poolId] = shareType;
        _poolIndex = poolId.add(1);

        emit NewPool(poolId, shareType);
    }

    function setRewardsDeductionRate(uint256 poolId, uint256 rate) public virtual {
        require(address(shareTypes(poolId)) != address(0), "Invalid pool");
        require(rate <= 1e18, "invalid rate");

        _rewardsDeductionRates[poolId] = rate;
        emit RewardsDeductionRateSet(poolId, rate);
    }

    function notifyRewardRule(uint256 poolId, IERC20 rewardType, uint256 rewardAmountAdd, uint256 rewardDuration)
        public
        virtual
        updateRewards(poolId, address(0))
    {
        require(address(rewardType) != address(0), "not allowed");
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

        // start a new reward period
        if (block.timestamp >= rewardRule.endTime) {
            rewardRule.rewardRate = rewardAmountAdd.div(rewardDuration);
        } else {
            uint256 remainingTime = rewardRule.endTime.sub(block.timestamp);
            uint256 leftover = remainingTime.mul(rewardRule.rewardRate);
            rewardRule.rewardRate = rewardAmountAdd.add(leftover).div(rewardDuration);
        }

        rewardRule.endTime = block.timestamp.add(rewardDuration);
        rewardRule.lastAccumulatedTime = block.timestamp;

        emit RewardRuleUpdated(poolId, rewardType, rewardRule.rewardRate, rewardRule.endTime);
    }

    function stake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "Cannot stake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "Invalid pool");

        shareType.safeTransferFrom(msg.sender, address(this), amount);

        _totalShares[poolId] = _totalShares[poolId].add(amount);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].add(amount);

        emit Staked(poolId, msg.sender, amount);

        return true;
    }

    function unstake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "Cannot unstake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "Invalid pool");

        _totalShares[poolId] = _totalShares[poolId].sub(amount);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].sub(amount);

        shareType.safeTransfer(msg.sender, amount);

        emit Unstaked(poolId, msg.sender, amount);

        return true;
    }

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
                    uint256 remainingTime = rewardRule.endTime.sub(rewardRule.lastAccumulatedTime);
                    uint256 addRewardRate = deduction.div(remainingTime);
                    rewardRule.rewardRate = rewardRule.rewardRate.add(addRewardRate);
                }

                types[i].safeTransfer(msg.sender, remainingReward);
                emit ClaimReward(poolId, types[i], msg.sender, remainingReward);
            }
        }

        return true;
    }

    function exit(uint256 poolId) external virtual override returns (bool) {
        unstake(poolId, shares(poolId, msg.sender));
        claimRewards(poolId);
        return true;
    }
}
