// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @title ILSTConvert Interface
/// @author Acala Developers
/// @notice You can use this convertor to convert token into LST.
interface ILSTConvert {
    /// @notice Get the input token type of this convertor.
    /// @return Returns (inputToken).
    function inputToken() external view returns (address);

    /// @notice Get the output token type of this convertor.
    /// @return Returns (outputToken).
    function outputToken() external view returns (address);

    /// @notice Convert `inputAmount` token.
    /// @param inputAmount The input token amount to convert.
    /// @return Returns (outputTokenAmount).
    function convert(uint256 inputAmount) external returns (uint256);

    /// @notice Convert `inputAmount` token and send output token to `receiver`.
    /// @param inputAmount The input token amount to convert.
    /// @param receiver The receiver for the converted output token.
    /// @return Returns Output token amount.
    function convertTo(
        uint256 inputAmount,
        address receiver
    ) external returns (uint256);
}
