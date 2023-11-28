# StableAssetStakeUtil

*Acala Developers*

> StableAssetStakeUtil Contract

Utilitity contract support batch these operation: 1. mint StaleAsset LP token 2. wrap LP token to Wrapped LP token 3. stake Wrapped LP token to Euphrates pool



## Methods

### euphrates

```solidity
function euphrates() external view returns (contract IStakingTo)
```

The token address of Euphrates.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IStakingTo | undefined |

### mintAndStake

```solidity
function mintAndStake(uint32 stableAssetPoolId, uint256[] assetsAmount, contract IERC20 stableAssetShareToken, contract IWrappedStableAssetShare wrappedShareToken, uint256 poolId) external nonpayable returns (bool)
```

Mint StalbeAsset LP token and stake it&#39;s wrapped token to Euphrates pool.

*it&#39;s not compitable with StableAsset TDOT pool becuase of the assets amount of LDOT is rebased.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| stableAssetPoolId | uint32 | The id of StableAsset pool. |
| assetsAmount | uint256[] | The amounts of assets of StableAsset pool used to mint. |
| stableAssetShareToken | contract IERC20 | The LP token of StableAsset pool. |
| wrappedShareToken | contract IWrappedStableAssetShare | The wrapper for StableAsset LP token. |
| poolId | uint256 | The if of Euphrates pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | Returns (success). |

### stableAsset

```solidity
function stableAsset() external view returns (contract IStableAsset)
```

The StableAsset predeploy contract address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IStableAsset | undefined |




