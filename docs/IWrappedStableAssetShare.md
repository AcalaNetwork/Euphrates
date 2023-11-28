# IWrappedStableAssetShare

*Acala Developers*

> IWrappedStableAssetShare Interface

You can use this to wrapped stable asset pool LP token to received market profit.



## Methods

### deposit

```solidity
function deposit(uint256 shareAmount) external nonpayable returns (uint256)
```

Deposit `shareAmount` share token to mint wrapped share token.



#### Parameters

| Name | Type | Description |
|---|---|---|
| shareAmount | uint256 | The share token amount to deposit. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (wrappedShareAmount). The wrapped share token amount received. |

### depositRate

```solidity
function depositRate() external view returns (uint256)
```

Get the deposit rate(the exchange rate for share token to wrapped share token).




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (exchangeRate). Deposit rate, 1e18 is 100% |

### withdraw

```solidity
function withdraw(uint256 wrappedShareAmount) external nonpayable returns (uint256)
```

Withdraw share token by burn `wrappedShareAmount` wrapped share token.



#### Parameters

| Name | Type | Description |
|---|---|---|
| wrappedShareAmount | uint256 | The wrapped share token amount to burn. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (shareAmount). The share token amount received. |

### withdrawRate

```solidity
function withdrawRate() external view returns (uint256)
```

Get the withdraw rate(the exchange rate for wrapped share token to share token).




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (exchangeRate). Withdraw rate, 1e18 is 100% |



## Events

### Deposit

```solidity
event Deposit(address indexed who, uint256 shareAmount, uint256 wrappedShareAmount)
```

Deposit share token to mint wrapped share token.



#### Parameters

| Name | Type | Description |
|---|---|---|
| who `indexed` | address | The sender of the transaction. |
| shareAmount  | uint256 | The share token amount to deposit. |
| wrappedShareAmount  | uint256 | The wrapped share token amount received. |

### Withdraw

```solidity
event Withdraw(address indexed who, uint256 wrappedShareAmount, uint256 shareAmount)
```

Withdraw share token by burn wrapped share token.



#### Parameters

| Name | Type | Description |
|---|---|---|
| who `indexed` | address | The sender of the transaction. |
| wrappedShareAmount  | uint256 | The wrapped share token amount to burn. |
| shareAmount  | uint256 | The share token amount received. |



