# LendingPoolDepositConvertor

*Acala Developers*

> LendingPoolDepositConvertor Contract

Convert token to lToken by LendingPool.deposit of Starley.



## Methods

### convert

```solidity
function convert(uint256 inputAmount) external nonpayable returns (uint256)
```

Convert `inputAmount` token.



#### Parameters

| Name | Type | Description |
|---|---|---|
| inputAmount | uint256 | The input token amount to convert. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns (outputTokenAmount). |

### convertTo

```solidity
function convertTo(uint256 inputAmount, address receiver) external nonpayable returns (uint256)
```

Convert `inputAmount` token and send output token to `receiver`.



#### Parameters

| Name | Type | Description |
|---|---|---|
| inputAmount | uint256 | The input token amount to convert. |
| receiver | address | The receiver for the converted output token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Returns Output token amount. |

### depositToken

```solidity
function depositToken() external view returns (address)
```

The token address to deposit.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### inputToken

```solidity
function inputToken() external view returns (address)
```

Get the input token type of this convertor.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | Returns (inputToken). |

### lendingPool

```solidity
function lendingPool() external view returns (address)
```

The Starlay LendingPool contract address.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### outputToken

```solidity
function outputToken() external view returns (address)
```

Get the output token type of this convertor.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | Returns (outputToken). |




