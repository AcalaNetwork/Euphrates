// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./IHoma.sol";
import "./IStableAsset.sol";

contract LSDStaking is Initializable, OwnableUpgradeable, PausableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct PoolInfo {
        IERC20 shareType;
        uint256 totalShare;
        uint256 rewardsDeductionRate; // deduct rate, e.g. 1e18 is 100%
    }

    struct RewardRule {
        uint256 rewardRate; // reward amount per second
        uint256 endTime;
        uint256 rewardRateAccumulated; // already mul 1e18 to avoid loss of precision
        uint256 lastAccumulatedTime;
    }

    enum UserOperation {
        Stake,
        Unstake,
        ClaimRewards
    }

    struct ConvertInfo {
        IERC20 convertedShareType;
        uint256 convertedExchangeRate; // 旧的shareToken 同转化后的 shareToken 的兑换比例， 1e18 是 100%
    }

    enum ConvertType {
        Lcdot2Ldot,
        Lcdot2Tdot
    }

    address public constant DOT = 0x0000000000000000000100000000000000000002;
    address public constant LCDOT = 0x000000000000000000040000000000000000000d;
    address public constant LDOT = 0x0000000000000000000100000000000000000003;
    address public constant TDOT = 0x0000000000000000000300000000000000000000;
    address public constant HOMA = 0x0000000000000000000000000000000000000805;
    address public constant STABLE_ASSET = 0x0000000000000000000000000000000000000804;
    address public constant LIQUID_CROWDLOAN = 0x0000000000000000000100000000000000000018; // TODO: config

    uint256 public constant MAX_REWARD_TYPES = 5;
    uint256 private _poolIndex = 0;
    mapping(uint256 => PoolInfo) private _pools;
    mapping(uint256 => IERC20[]) private _rewardTypes;
    mapping(uint256 => mapping(IERC20 => RewardRule)) private _rewardRules;
    mapping(uint256 => mapping(address => uint256)) private _shares;
    mapping(uint256 => mapping(address => mapping(IERC20 => uint256))) private _rewards;
    mapping(uint256 => mapping(address => mapping(IERC20 => uint256))) private _paidAccumulatedRates;
    mapping(uint256 => mapping(UserOperation => bool)) private _prohibitedOperations;
    mapping(uint256 => ConvertInfo) private _convertInfos;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __Ownable_init();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function poolIndex() public view returns (uint256) {
        return _poolIndex;
    }

    function pools(uint256 poolId) public view returns (PoolInfo memory) {
        return _pools[poolId];
    }

    function rewardTypes(uint256 poolId) public view returns (IERC20[] memory) {
        return _rewardTypes[poolId];
    }

    function rewardRules(uint256 poolId, IERC20 rewardType) public view returns (RewardRule memory) {
        return _rewardRules[poolId][rewardType];
    }

    function shares(uint256 poolId, address account) public view returns (uint256) {
        return _shares[poolId][account];
    }

    function rewards(uint256 poolId, address account, IERC20 rewardType) public view returns (uint256) {
        return _rewards[poolId][account][rewardType];
    }

    function paidAccumulatedRates(uint256 poolId, address account, IERC20 rewardType) public view returns (uint256) {
        return _paidAccumulatedRates[poolId][account][rewardType];
    }

    function prohibitedOperations(uint256 poolId, UserOperation operation) public view returns (bool) {
        return _prohibitedOperations[poolId][operation];
    }

    function convertInfos(uint256 poolId) public view returns (ConvertInfo memory) {
        return _convertInfos[poolId];
    }

    function lastTimeRewardApplicable(uint256 poolId, IERC20 rewardType) public view returns (uint256) {
        uint256 endTime = rewardRules(poolId, rewardType).endTime;
        return block.timestamp < endTime ? block.timestamp : endTime;
    }

    function rewardPerShare(uint256 poolId, IERC20 rewardType) public view returns (uint256) {
        PoolInfo memory pool = pools(poolId);
        RewardRule memory rewardRule = rewardRules(poolId, rewardType);

        if (pool.totalShare == 0) {
            return rewardRule.rewardRateAccumulated;
        }

        uint256 pendingRewardRate = lastTimeRewardApplicable(poolId, rewardType).sub(rewardRule.lastAccumulatedTime).mul(
            rewardRule.rewardRate
        ).mul(1e18).div(pool.totalShare); // mul 10**18 to avoid loss of precision

        return rewardRule.rewardRateAccumulated.add(pendingRewardRate);
    }

    function earned(uint256 poolId, address account, IERC20 rewardType) public view returns (uint256) {
        uint256 share = shares(poolId, account);
        uint256 reward = rewards(poolId, account, rewardType);
        uint256 paidAccumulatedRate = paidAccumulatedRates(poolId, account, rewardType);
        uint256 pendingReward = share.mul(rewardPerShare(poolId, rewardType).sub(paidAccumulatedRate)).div(1e18); // div 10**18 that was mul in rewardPerShare

        return reward.add(pendingReward);
    }

    function setProhibitedOperation(uint256 poolId, UserOperation operation, bool prohibite)
        external
        onlyOwner
        whenNotPaused
    {
        // do not check poolId, so that can set in advance.
        _prohibitedOperations[poolId][operation] = prohibite;

        emit ProhibitedOperationSet(poolId, operation, prohibite);
    }

    function addPool(IERC20 shareType) external onlyOwner whenNotPaused {
        require(address(shareType) != address(0), "0 address not allowed");
        uint256 poolId = poolIndex();
        _pools[poolId] = PoolInfo({shareType: shareType, totalShare: 0, rewardsDeductionRate: 0});

        // update pool index
        _poolIndex = poolId.add(1);

        emit NewPool(poolId, shareType);
    }

    function setRewardsDeductionRate(uint256 poolId, uint256 rate) public onlyOwner whenNotPaused {
        require(address(pools(poolId).shareType) != address(0), "Invalid pool");
        require(rate <= 1e18, "invalid rate");

        _pools[poolId].rewardsDeductionRate = rate;
        emit RewardsDeductionRateSet(poolId, rate);
    }

    function notifyRewardRule(uint256 poolId, IERC20 rewardType, uint256 rewardAmountAdd, uint256 rewardDuration)
        external
        onlyOwner
        whenNotPaused
        updateRewards(poolId, address(0))
    {
        require(address(rewardType) != address(0), "not allowed");
        require(address(pools(poolId).shareType) != address(0), "pool must be existed");

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

    function convertLSDPool(uint256 poolId, ConvertType convertType) external onlyOwner whenNotPaused {
        PoolInfo memory pool = pools(poolId);
        require(address(pool.shareType) == LCDOT, "Share token must be Lcdot");

        ConvertInfo storage convert = _convertInfos[poolId];
        require(address(convert.convertedShareType) == address(0), "Already converted");

        // TODO: call the LIQUID_CROWDLOAN to convert LcDOT to DOT;
        uint256 amount = pools(poolId).totalShare;

        if (convertType == ConvertType.Lcdot2Ldot) {
            uint256 exchangeRate = IHoma(HOMA).getExchangeRate();
            require(exchangeRate != 0, "exchange rate shouldn't be zero");

            uint256 beforeLdotAmount = IERC20(LDOT).balanceOf(address(this));
            IHoma(HOMA).mint(amount);
            uint256 afterLdotAmount = IERC20(LDOT).balanceOf(address(this));

            require(
                amount.mul(exchangeRate).div(1e18).add(beforeLdotAmount) <= afterLdotAmount, "invalid exchange rate"
            );

            convert.convertedShareType = IERC20(LDOT);
            convert.convertedExchangeRate = exchangeRate;
        } else if (convertType == ConvertType.Lcdot2Tdot) {
            uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = amount;
            amounts[1] = 0;
            IStableAsset(STABLE_ASSET).stableAssetMint(0, amounts, 0);
            uint256 afterTdotAmount = IERC20(TDOT).balanceOf(address(this));
            uint256 exchangeRate = afterTdotAmount.sub(beforeTdotAmount).mul(1e18).div(amount);

            require(exchangeRate != 0, "exchange rate shouldn't be zero");

            convert.convertedShareType = IERC20(TDOT);
            convert.convertedExchangeRate = exchangeRate;
        }

        emit LSDPoolConverted(poolId, pool.shareType, convert.convertedShareType, convert.convertedExchangeRate);
    }

    function stake(uint256 poolId, uint256 amount)
        external
        whenNotPaused
        operationNotProhibited(poolId, UserOperation.Stake)
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "Cannot stake 0");
        PoolInfo storage pool = _pools[poolId];
        require(address(pool.shareType) != address(0), "Invalid pool");

        ConvertInfo memory convertInfo = convertInfos(poolId);
        if (address(convertInfo.convertedShareType) != address(0)) {
            uint256 convertedAmount = amount.mul(convertInfo.convertedExchangeRate).div(1e18);
            require(convertedAmount != 0, "shouldn't be zero");

            convertInfo.convertedShareType.safeTransferFrom(msg.sender, address(this), convertedAmount);
        } else {
            pool.shareType.safeTransferFrom(msg.sender, address(this), amount);
        }

        pool.totalShare = pool.totalShare.add(amount);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].add(amount);

        emit Staked(poolId, msg.sender, amount);

        return true;
    }

    function unstake(uint256 poolId, uint256 amount)
        public
        whenNotPaused
        operationNotProhibited(poolId, UserOperation.Unstake)
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "Cannot unstake 0");
        PoolInfo storage pool = _pools[poolId];
        require(address(pool.shareType) != address(0), "Invalid pool");

        pool.totalShare = pool.totalShare.sub(amount);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].sub(amount);

        ConvertInfo memory convertInfo = convertInfos(poolId);
        if (address(convertInfo.convertedShareType) != address(0)) {
            uint256 convertedAmount = amount.mul(convertInfo.convertedExchangeRate).div(1e18);
            require(convertedAmount != 0, "shouldn't be zero");

            convertInfo.convertedShareType.safeTransfer(msg.sender, convertedAmount);
        } else {
            pool.shareType.safeTransfer(msg.sender, amount);
        }

        emit Unstaked(poolId, msg.sender, amount);

        return true;
    }

    function claimRewards(uint256 poolId)
        public
        whenNotPaused
        operationNotProhibited(poolId, UserOperation.ClaimRewards)
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        IERC20[] memory types = rewardTypes(poolId);
        uint256 deductionRate = pools(poolId).rewardsDeductionRate;

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

    function exit(uint256 poolId) external returns (bool) {
        unstake(poolId, shares(poolId, msg.sender));
        claimRewards(poolId);
        return true;
    }

    event LSDPoolConverted(uint256 poolId, IERC20 beforeShareType, IERC20 afterShareType, uint256 exchangeRate);
    event ClaimReward(uint256 poolId, IERC20 rewardType, address account, uint256 amount);
    event Unstaked(uint256 poolId, address account, uint256 amount);
    event Staked(uint256 poolId, address account, uint256 amount);
    event RewardRuleUpdated(uint256 poolId, IERC20 rewardType, uint256 rewardRate, uint256 endTime);
    event NewPool(uint256 poolId, IERC20 shareType);
    event RewardsDeductionRateSet(uint256 poolId, uint256 rate);
    event ProhibitedOperationSet(uint256 poolId, UserOperation operation, bool prohibited);

    modifier operationNotProhibited(uint256 poolId, UserOperation operation) {
        require(prohibitedOperations(poolId, operation) == false, "The pool prohibited this operation.");
        _;
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
}
