# LendingPoolStakeUtil

*Acala Developers*

> LendingPoolStakeUtil Contract

Utilitity contract support batch these operation: 1. deposit token to LendingPool to get lToken 2. stake lToken to Euphrates pool



## Methods

### depositAndStake

```solidity
function depositAndStake(contract IERC20 asset, uint256 amount, uint256 poolId) external nonpayable returns (bool)
```

Deposit token to LendingPool and stake lToken to Euphrates pool.



#### Parameters

| Name | Type | Description |
|---|---|---|
| asset | contract IERC20 | The token to deposit LendingPool. |
| amount | uint256 | The amount of token to deposit. |
| poolId | uint256 | The id of Euphrates pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

### euphrates

```solidity
function euphrates() external view returns (contract IStakingTo)
```

The token address of Euphrates.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IStakingTo | undefined |

### lendingPool

```solidity
function lendingPool() external view returns (contract ILendingPool)
```

The Starlay LendingPool contract address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ILendingPool | undefined |




