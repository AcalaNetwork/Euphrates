# UpgradeableStakingCommon

*Acala Developers*

> UpgradeableStakingCommon Contract

You can use this contract as a base contract for staking.

*This contract derived OwnableUpgradeable, PausableUpgradeable and PoolOperationPausable, and overrides some functions to add access control for these. This version conforms to the specification for upgradeable contracts.*

## Methods

### MAX_REWARD_TYPES

```solidity
function MAX_REWARD_TYPES() external view returns (uint256)
```

The maximum number of reward types for a staking pool. When distribute and receiving rewards, all reward types of a pool will be iterated. Limit the number of reward types to avoid out of huge gas.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### addPool

```solidity
function addPool(contract IERC20 shareType) external nonpayable
```

Initialize a staking pool for `shareType`.

*Override the inherited function to define access control.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| shareType | contract IERC20 | The share token. |

### claimRewards

```solidity
function claimRewards(uint256 poolId) external nonpayable returns (bool)
```

Claim all rewards from staking pool.

*Override the inherited function to define access control.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

### earned

```solidity
function earned(uint256 poolId, address account, contract IERC20 rewardType) external view returns (uint256)
```

Get `who`&#39;s unclaimed reward amount of specific `rewardType` at `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| account | address | undefined |
| rewardType | contract IERC20 | The reward token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (rewardAmount). |

### exit

```solidity
function exit(uint256 poolId) external nonpayable returns (bool)
```

Unstake all staked share and claim all unclaimed rewards from staking pool.

*Override the inherited function to define access control.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

### initialize

```solidity
function initialize() external nonpayable
```

The initialize function.

*proxy contract will call this when firstly fetch this contract as the implementation contract.*


### lastTimeRewardApplicable

```solidity
function lastTimeRewardApplicable(uint256 poolId, contract IERC20 rewardType) external view returns (uint256)
```

Get lastest time that can be used to accumulate rewards for `rewardType` reward of `poolId` pool.

*If rule has ended, return the end time. Otherwise return the block time.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| rewardType | contract IERC20 | The reward token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns timestamp. |

### notifyRewardRule

```solidity
function notifyRewardRule(uint256 poolId, contract IERC20 rewardType, uint256 rewardAmountAdd, uint256 rewardDuration) external nonpayable
```

Start or adjust the reward rule of `rewardType` for `poolId` pool.

*Override the inherited function to define access control.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| rewardType | contract IERC20 | The reward token. |
| rewardAmountAdd | uint256 | The reward token added. |
| rewardDuration | uint256 | The reward accumulate lasting time. |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### paidAccumulatedRates

```solidity
function paidAccumulatedRates(uint256 poolId, address account, contract IERC20 rewardType) external view returns (uint256)
```

Get the paid accumulated rate of `rewardType` for `account` of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| account | address | The staker. |
| rewardType | contract IERC20 | The reward token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns rate. |

### pause

```solidity
function pause() external nonpayable
```

Puase the contract by Pausable.

*Only the owner of Ownable can call this function.*


### paused

```solidity
function paused() external view returns (bool)
```



*Returns true if the contract is paused, and false otherwise.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### pausedPoolOperations

```solidity
function pausedPoolOperations(uint256 poolId, enum PoolOperationPausable.Operation operation) external view returns (bool)
```

Get the pause status of `operation` for `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| operation | enum PoolOperationPausable.Operation | The user operation. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns True means paused. |

### poolIndex

```solidity
function poolIndex() external view returns (uint256)
```

Get the index of next pool. It&#39;s equal to the current count of pools.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns the next pool index. |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby disabling any functionality that is only available to the owner.*


### rewardPerShare

```solidity
function rewardPerShare(uint256 poolId, contract IERC20 rewardType) external view returns (uint256)
```

Get the exchange rate for share to `rewardType` reward token of `poolId` pool.

*The reward part is accumulated rate adds pending to accumulate rate, it&#39;s used to calculate reward. 1e18 is 100%.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| rewardType | contract IERC20 | The reward token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns rate. |

### rewardRules

```solidity
function rewardRules(uint256 poolId, contract IERC20 rewardType) external view returns (struct Staking.RewardRule)
```

Get the reward rule for `rewardType` reward of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| rewardType | contract IERC20 | The reward token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Staking.RewardRule | Returns reward rule. |

### rewardTypes

```solidity
function rewardTypes(uint256 poolId) external view returns (contract IERC20[])
```

Get the reward token types of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20[] | Returns reward token array. |

### rewards

```solidity
function rewards(uint256 poolId, address account, contract IERC20 rewardType) external view returns (uint256)
```

Get the unclaimed paid `rewardType` reward amount for `acount` of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| account | address | The staker. |
| rewardType | contract IERC20 | The reward token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns reward amount. |

### rewardsDeductionRates

```solidity
function rewardsDeductionRates(uint256 poolId) external view returns (uint256)
```

Get the rewards decution rate of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns deduction rate. |

### setPoolOperationPause

```solidity
function setPoolOperationPause(uint256 poolId, enum PoolOperationPausable.Operation operation, bool paused) external nonpayable
```

Set the `paused` status of `operation` for `poolId` pool.

*Override the inherited function to define access control.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| operation | enum PoolOperationPausable.Operation | The user operation. |
| paused | bool | The pause status. |

### setRewardsDeductionRate

```solidity
function setRewardsDeductionRate(uint256 poolId, uint256 rate) external nonpayable
```

Set deduction `rate` of claim rewards for `poolId` pool.

*Override the inherited function to define access control.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| rate | uint256 | The deduction rate. 1e18 is 100% |

### shareTypes

```solidity
function shareTypes(uint256 poolId) external view returns (contract IERC20)
```

Get the share token of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | Returns share token. |

### shares

```solidity
function shares(uint256 poolId, address account) external view returns (uint256)
```

Get the share amount of `account` of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| account | address | The staker. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns share amount. |

### stake

```solidity
function stake(uint256 poolId, uint256 amount) external nonpayable returns (bool)
```

Stake share into staking pool.

*Override the inherited function to define access control.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| amount | uint256 | The share amount to stake. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

### totalShares

```solidity
function totalShares(uint256 poolId) external view returns (uint256)
```

Get the total share amount of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns total share amount. |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### unpause

```solidity
function unpause() external nonpayable
```

Unpuase the contract by Pausable.

*Only the owner of Ownable can call this function.*


### unstake

```solidity
function unstake(uint256 poolId, uint256 amount) external nonpayable returns (bool)
```

Withdraw share from staking pool.

*Override the inherited function to define access control.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |



## Events

### ClaimReward

```solidity
event ClaimReward(address indexed sender, uint256 poolId, contract IERC20 indexed rewardType, uint256 amount)
```

Claim reward from staking pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| sender `indexed` | address | undefined |
| poolId  | uint256 | undefined |
| rewardType `indexed` | contract IERC20 | undefined |
| amount  | uint256 | undefined |

### Initialized

```solidity
event Initialized(uint8 version)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| version  | uint8 | undefined |

### NewPool

```solidity
event NewPool(uint256 poolId, contract IERC20 shareType)
```

New staking pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | undefined |
| shareType  | contract IERC20 | undefined |

### OperationPauseStatusSet

```solidity
event OperationPauseStatusSet(uint256 poolId, enum PoolOperationPausable.Operation operation, bool paused)
```

The user operation pause status of `poolId` pool updated.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | undefined |
| operation  | enum PoolOperationPausable.Operation | undefined |
| paused  | bool | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### Paused

```solidity
event Paused(address account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

### RewardRuleUpdate

```solidity
event RewardRuleUpdate(uint256 poolId, contract IERC20 rewardType, uint256 rewardRate, uint256 endTime)
```

The rule for `rewardType` token at `poolId` pool updated.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | undefined |
| rewardType  | contract IERC20 | undefined |
| rewardRate  | uint256 | undefined |
| endTime  | uint256 | undefined |

### RewardsDeductionRateSet

```solidity
event RewardsDeductionRateSet(uint256 poolId, uint256 rate)
```

The deduction rate for all `rewardType` rewards of `poolId` pool updated.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | undefined |
| rate  | uint256 | undefined |

### Stake

```solidity
event Stake(address indexed sender, uint256 poolId, uint256 amount)
```

Stake share into staking pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| sender `indexed` | address | undefined |
| poolId  | uint256 | undefined |
| amount  | uint256 | undefined |

### Unpaused

```solidity
event Unpaused(address account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

### Unstake

```solidity
event Unstake(address indexed sender, uint256 poolId, uint256 amount)
```

Unstake share from staking pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| sender `indexed` | address | undefined |
| poolId  | uint256 | undefined |
| amount  | uint256 | undefined |


