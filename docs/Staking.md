# Staking

*Acala Developers*

> Staking Abstract Contract

Staking supports multiple reward tokens and rewards claim deduction pubnishment. Deduction rewards will be distributed to all stakers in the pool.

*This contract does not define access control for functions, you should override these define in the derived contract.*

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

*you should override this function to define access control in the derived contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| shareType | contract IERC20 | The share token. |

### claimRewards

```solidity
function claimRewards(uint256 poolId) external nonpayable returns (bool)
```

Claim all rewards from staking pool.



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
function earned(uint256 poolId, address who, contract IERC20 rewardType) external view returns (uint256)
```

Get `who`&#39;s unclaimed reward amount of specific `rewardType` at `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| who | address | The address of staker. |
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



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

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

*you should override this function to define access control in the derived contract. It can start a new period reward, or add extra reward amount for ative rule, or ajust reward rate by adjust rewardDuration but it cannot slash un-accumulate reward from ative rule.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| rewardType | contract IERC20 | The reward token. |
| rewardAmountAdd | uint256 | The reward token added. |
| rewardDuration | uint256 | The reward accumulate lasting time. |

### paidAccumulatedRates

```solidity
function paidAccumulatedRates(uint256 poolId, address who, contract IERC20 rewardType) external view returns (uint256)
```

Get the paid accumulated rate of `rewardType` for `who` of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| who | address | The staker. |
| rewardType | contract IERC20 | The reward token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns rate. |

### poolIndex

```solidity
function poolIndex() external view returns (uint256)
```

Get the index of next pool. It&#39;s equal to the current count of pools.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns the next pool index. |

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
function rewards(uint256 poolId, address who, contract IERC20 rewardType) external view returns (uint256)
```

Get the unclaimed paid `rewardType` reward amount for `who` of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| who | address | The staker. |
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

### setRewardsDeductionRate

```solidity
function setRewardsDeductionRate(uint256 poolId, uint256 rate) external nonpayable
```

Set deduction `rate` of claim rewards for `poolId` pool.

*you should override this function to define access control in the derived contract.*

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
function shares(uint256 poolId, address who) external view returns (uint256)
```

Get the share amount of `who` of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| who | address | The staker. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns share amount. |

### stake

```solidity
function stake(uint256 poolId, uint256 amount) external nonpayable returns (bool)
```

Stake share into staking pool.



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

### unstake

```solidity
function unstake(uint256 poolId, uint256 amount) external nonpayable returns (bool)
```

Withdraw share from staking pool.



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

### NewPool

```solidity
event NewPool(uint256 poolId, contract IERC20 shareType)
```

New staking pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | The index of staking pool. |
| shareType  | contract IERC20 | The share token of this staking pool. |

### RewardRuleUpdate

```solidity
event RewardRuleUpdate(uint256 poolId, contract IERC20 rewardType, uint256 rewardRate, uint256 endTime)
```

The rule for `rewardType` token at `poolId` pool updated.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | The index of staking pool. |
| rewardType  | contract IERC20 | The reward token. |
| rewardRate  | uint256 | The amount of `rewardType` token will accumulate per second. |
| endTime  | uint256 | The end time of this reward rule. |

### RewardsDeductionRateSet

```solidity
event RewardsDeductionRateSet(uint256 poolId, uint256 rate)
```

The deduction rate for all `rewardType` rewards of `poolId` pool updated.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | The index of staking pool. |
| rate  | uint256 | The deduction rate. |

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



