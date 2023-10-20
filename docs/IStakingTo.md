# IStakingTo

*Acala Developers*

> IStakingTo Interface

You can use this integrate Acala LST staking into your contract.



## Methods

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

### rewardTypes

```solidity
function rewardTypes(uint256 poolId) external view returns (contract IERC20[])
```

Get the all reward token types of the `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20[] | Returns (rewardTypesArr). Return all rewarded token types in this pool. |

### shareTypes

```solidity
function shareTypes(uint256 poolId) external view returns (contract IERC20)
```

Get the share token address of the `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | Returns (shareToken). If pool hasn&#39;t been initialized, return address(0x0). |

### shares

```solidity
function shares(uint256 poolId, address who) external view returns (uint256)
```

Get the share amount of `who` at `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| who | address | The address of staker. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (shareAmount). |

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

### stakeTo

```solidity
function stakeTo(uint256 poolId, uint256 amount, address receiver) external nonpayable returns (bool)
```

Stake share to other.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| amount | uint256 | The share amount to stake. |
| receiver | address | The share receiver. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

### totalShares

```solidity
function totalShares(uint256 poolId) external view returns (uint256)
```

Get the total share amount of the `poolId` pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (totalShare). |

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



