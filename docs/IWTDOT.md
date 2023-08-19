# IWTDOT

*Acala Developers*

> IWTDOT Interface

You can use this integrate with WrappedTDOT.



## Methods

### deposit

```solidity
function deposit(uint256 tdotAmount) external nonpayable returns (uint256)
```

Deposit `tdotAmount` TDOT to mint WTDOT.



#### Parameters

| Name | Type | Description |
|---|---|---|
| tdotAmount | uint256 | The TDOT amount to deposit. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (wtdotAmount). The WTDOT amount received. |

### depositRate

```solidity
function depositRate() external view returns (uint256)
```

Get the deposit rate(the exchange rate for TDOT to WTDOT).




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (exchangeRate). Deposit rate, 1e18 is 100% |

### withdraw

```solidity
function withdraw(uint256 wtdotAmount) external nonpayable returns (uint256)
```

Withdraw TDOT by burn `wtdotAmount` WTDOT.



#### Parameters

| Name | Type | Description |
|---|---|---|
| wtdotAmount | uint256 | The WTDOT amount to burn. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (tdotAmount). The TDOT amount received. |

### withdrawRate

```solidity
function withdrawRate() external view returns (uint256)
```

Get the withdraw rate(the exchange rate for WTDOT to TDOT).




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (exchangeRate). Withdraw rate, 1e18 is 100% |



## Events

### Deposit

```solidity
event Deposit(address indexed who, uint256 tdotAmount, uint256 wtdotAmount)
```

Deposit TDOT to mint WTDOT.



#### Parameters

| Name | Type | Description |
|---|---|---|
| who `indexed` | address | The sender of the transaction. |
| tdotAmount  | uint256 | The TDOT amount to deposit. |
| wtdotAmount  | uint256 | The WTDOT amount received. |

### Withdraw

```solidity
event Withdraw(address indexed who, uint256 wtdotAmount, uint256 tdotAmount)
```

Withdraw TDOT by burn WTDOT.



#### Parameters

| Name | Type | Description |
|---|---|---|
| who `indexed` | address | The sender of the transaction. |
| wtdotAmount  | uint256 | The WTDOT amount to burn. |
| tdotAmount  | uint256 | The TDOT amount received. |



