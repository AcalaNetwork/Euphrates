# ILSTConvert

*Acala Developers*

> ILSTConvert Interface

You can use this convertor to convert token into LST.



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

### inputToken

```solidity
function inputToken() external view returns (address)
```

Get the input token type of this convertor.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | Returns (inputToken). |

### outputToken

```solidity
function outputToken() external view returns (address)
```

Get the output token type of this convertor.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | Returns (outputToken). |




