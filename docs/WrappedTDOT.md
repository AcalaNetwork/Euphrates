# WrappedTDOT

*Acala Developers*

> WrappedTDOT Contract

To wrap TDOT, TDOT is the LP token of Taiga&#39;s StableAsset(DOT-LDOT) pool on Acala. The TDOT holders can receive TDOT as the LP fee by claim. So WTDOT and DOT do not maintain a 1:1 ratio.



## Methods

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### allowance

```solidity
function allowance(address, address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### approve

```solidity
function approve(address spender, uint256 amount) external nonpayable returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### balanceOf

```solidity
function balanceOf(address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### decimals

```solidity
function decimals() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

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

### name

```solidity
function name() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### nonces

```solidity
function nonces(address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### permit

```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |
| value | uint256 | undefined |
| deadline | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

### symbol

```solidity
function symbol() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### tdot

```solidity
function tdot() external view returns (address)
```

The token address of TDOT.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) external nonpayable returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

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

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| amount  | uint256 | undefined |

### Deposit

```solidity
event Deposit(address indexed who, uint256 tdotAmount, uint256 wtdotAmount)
```

Deposit TDOT to mint WTDOT.



#### Parameters

| Name | Type | Description |
|---|---|---|
| who `indexed` | address | undefined |
| tdotAmount  | uint256 | undefined |
| wtdotAmount  | uint256 | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| amount  | uint256 | undefined |

### Withdraw

```solidity
event Withdraw(address indexed who, uint256 wtdotAmount, uint256 tdotAmount)
```

Withdraw TDOT by burn WTDOT.



#### Parameters

| Name | Type | Description |
|---|---|---|
| who `indexed` | address | undefined |
| wtdotAmount  | uint256 | undefined |
| tdotAmount  | uint256 | undefined |



