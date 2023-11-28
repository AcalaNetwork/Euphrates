# DOT2WTDOTConvertor

*Acala Developers*

> DOT2WTDOTConvertor Contract

Convert DOT to WTDOT by Homa protocal, StableAsset of Acala and WTDOT contract.



## Methods

### HOMA_MINT_THRESHOLD

```solidity
function HOMA_MINT_THRESHOLD() external view returns (uint256)
```

The threshold amount of DOT to mint by HOMA.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### dot

```solidity
function dot() external view returns (address)
```

The token address of DOT.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### homa

```solidity
function homa() external view returns (address)
```

The Homa predeployed contract of Acala.




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

### ldot

```solidity
function ldot() external view returns (address)
```

The token address of LDOT.




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

### stableAsset

```solidity
function stableAsset() external view returns (address)
```

The StableAsset predeployed contract of Acala.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### tdot

```solidity
function tdot() external view returns (address)
```

The token address of TDOT.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### wtdot

```solidity
function wtdot() external view returns (address)
```

The token address of WTDOT.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |




