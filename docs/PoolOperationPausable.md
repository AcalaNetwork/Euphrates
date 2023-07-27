# PoolOperationPausable

*Acala Developers*

> PoolOperationPausable Contract

You can add modifier to functions to pause/unpause user operation for each pool by inherit this contract.

*This contract does not define access control for functions, you should override these define in the derived contract.*

## Methods

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

### setPoolOperationPause

```solidity
function setPoolOperationPause(uint256 poolId, enum PoolOperationPausable.Operation operation, bool paused) external nonpayable
```

Set the `paused` status of `operation` for `poolId` pool.

*you should override this function to define access control in the derived contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId | uint256 | The index of staking pool. |
| operation | enum PoolOperationPausable.Operation | The user operation. |
| paused | bool | The pause status. |



## Events

### OperationPauseStatusSet

```solidity
event OperationPauseStatusSet(uint256 poolId, enum PoolOperationPausable.Operation operation, bool paused)
```

The user operation pause status of `poolId` pool updated.



#### Parameters

| Name | Type | Description |
|---|---|---|
| poolId  | uint256 | The index of staking pool. |
| operation  | enum PoolOperationPausable.Operation | The user operation. |
| paused  | bool | True is paused, false is unpaused. |



