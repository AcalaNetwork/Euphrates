# UpgradeableStakingLST

*Acala Developers*

> UpgradeableStakingLST Contract

This staking contract can convert the share token to it&#39;s LST. It just support LcDOT token on Acala.

*After pool&#39;s share is converted into its LST token, this pool can be staked with LST token and before token both. This version conforms to the specification for upgradeable contracts.*

## Methods

### DOT

```solidity
function DOT() external view returns (address)
```

The DOT token address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### HOMA

```solidity
function HOMA() external view returns (address)
```

The Homa predeploy contract address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### HOMA_MINT_THRESHOLD

```solidity
function HOMA_MINT_THRESHOLD() external view returns (uint256)
```

The threshold amount of DOT to mint by HOMA.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### LCDOT

```solidity
function LCDOT() external view returns (address)
```

The LcDOT token address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### LDOT

```solidity
function LDOT() external view returns (address)
```

The LDOT token address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### LIQUID_CROWDLOAN

```solidity
function LIQUID_CROWDLOAN() external view returns (address)
```

The LiquidCrowdloan predeploy contract address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### MAX_REWARD_TYPES

```solidity
function MAX_REWARD_TYPES() external view returns (uint256)
```

The maximum number of reward types for a staking pool. When distribute and receiving rewards, all reward types of a pool will be iterated. Limit the number of reward types to avoid out of huge gas.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### STABLE_ASSET

```solidity
function STABLE_ASSET() external view returns (address)
```

The StableAsset predeploy contract address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### TDOT

```solidity
function TDOT() external view returns (address)
```

The tDOT token address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### WTDOT

```solidity
function WTDOT() external view returns (address)
```

The Wrapped TDOT (WTDOT) token address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### addPool

```solidity
function addPool(contract IERC20 shareType) external nonpayable
```

Initialize a staking pool for `shareType`.

*Override the inherited function to define `onlyOwner` and `whenNotPaused` access.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| shareType | contract IERC20 | The share token. |

### claimRewards

```solidity
function claimRewards(uint256 poolId) external nonpayable returns (bool)
```

Claim all rewards from staking pool.

*Override the inherited function to define `whenNotPaused` and `poolOperationNotPaused(poolId, Operation.ClaimRewards)`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

### convertInfos

```solidity
function convertInfos(uint256 poolId) external view returns (struct UpgradeableStakingLST.ConvertInfo)
```

Get the LST convertion info of `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | UpgradeableStakingLST.ConvertInfo | Returns convert info. |

### convertLSTPool

```solidity
function convertLSTPool(uint256 poolId, enum UpgradeableStakingLST.ConvertType convertType) external nonpayable
```

convert the share token of ‘poolId’ pool to LST token by `convertType`.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| convertType | enum UpgradeableStakingLST.ConvertType | The convert type. |

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

*Override the inherited function to define access.*

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



*overwrite initialize() to mute initializer of UpgradeableStakingCommon*


### initialize

```solidity
function initialize(address dot, address lcdot, address ldot, address tdot, address homa, address stableAsset, address liquidCrowdloan, address wtdot) external nonpayable
```

The initialize function.

*proxy contract will call this when firstly fetch this contract as the implementation contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| dot | address | undefined |
| lcdot | address | undefined |
| ldot | address | undefined |
| tdot | address | undefined |
| homa | address | undefined |
| stableAsset | address | undefined |
| liquidCrowdloan | address | undefined |
| wtdot | address | undefined |

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

### pause

```solidity
function pause() external nonpayable
```

Puase the contract by Pausable.

*Define the `onlyOwner` access.*


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

### setPoolOperationPause

```solidity
function setPoolOperationPause(uint256 poolId, enum PoolOperationPausable.Operation operation, bool paused) external nonpayable
```

Set the `paused` status of `operation` for `poolId` pool.

*Override the inherited function to define `onlyOwner` and `whenNotPaused` access.*

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

*Override the inherited function to define `onlyOwner` and `whenNotPaused` access.*

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

Stake `amount` share token to `poolId` pool. If pool has been converted, still stake before share token.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| amount | uint256 | The amount of share token to stake. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

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

*Define the `onlyOwner` access.*


### unstake

```solidity
function unstake(uint256 poolId, uint256 amount) external nonpayable returns (bool)
```

Unstake `amount` share token from `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| amount | uint256 | The share token amount to unstake. If pool has been converted, it&#39;s converted share token amount, not the share amount. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

### updateRewardRule

```solidity
function updateRewardRule(uint256 poolId, contract IERC20 rewardType, uint256 rewardRate, uint256 endTime) external nonpayable
```

Update the reward rule of `rewardType` for `poolId` pool.

*Override the inherited function to define `onlyOwner` and `whenNotPaused` access.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| rewardType | contract IERC20 | The reward token. |
| rewardRate | uint256 | The reward amount per second. |
| endTime | uint256 | The end time of fule. |



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

### LSTPoolConverted

```solidity
event LSTPoolConverted(uint256 poolId, contract IERC20 beforeShareType, contract IERC20 afterShareType, uint256 beforeShareTokenAmount, uint256 afterShareTokenAmount)
```

The pool&#39;s share token is converted into its LST token.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | The pool id. |
| beforeShareType  | contract IERC20 | The share token before converted. |
| afterShareType  | contract IERC20 | The share token after converted. |
| beforeShareTokenAmount  | uint256 | The share token amount before converted. |
| afterShareTokenAmount  | uint256 | The share token amount after converted. |

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



