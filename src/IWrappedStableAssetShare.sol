// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/// @title IWrappedStableAssetShare Interface
/// @author Acala Developers
/// @notice You can use this to wrapped stable asset pool LP token to received market profit.
interface IWrappedStableAssetShare {
    /// @notice Deposit share token to mint wrapped share token.
    /// @param who The sender of the transaction.
    /// @param shareAmount The share token amount to deposit.
    /// @param wrappedShareAmount The wrapped share token amount received.
    event Deposit(address indexed who, uint256 shareAmount, uint256 wrappedShareAmount);

    /// @notice Withdraw share token by burn wrapped share token.
    /// @param who The sender of the transaction.
    /// @param wrappedShareAmount The wrapped share token amount to burn.
    /// @param shareAmount The share token amount received.
    event Withdraw(address indexed who, uint256 wrappedShareAmount, uint256 shareAmount);

    /// @notice Get the deposit rate(the exchange rate for share token to wrapped share token).
    /// @return Returns (exchangeRate). Deposit rate, 1e18 is 100%
    function depositRate() external view returns (uint256);

    /// @notice Get the withdraw rate(the exchange rate for wrapped share token to share token).
    /// @return Returns (exchangeRate). Withdraw rate, 1e18 is 100%
    function withdrawRate() external view returns (uint256);

    /// @notice Deposit `shareAmount` share token to mint wrapped share token.
    /// @param shareAmount The share token amount to deposit.
    /// @return Returns (wrappedShareAmount). The wrapped share token amount received.
    function deposit(uint256 shareAmount) external returns (uint256);

    /// @notice Withdraw share token by burn `wrappedShareAmount` wrapped share token.
    /// @param wrappedShareAmount The wrapped share token amount to burn.
    /// @return Returns (shareAmount). The share token amount received.
    function withdraw(uint256 wrappedShareAmount) external returns (uint256);
}
