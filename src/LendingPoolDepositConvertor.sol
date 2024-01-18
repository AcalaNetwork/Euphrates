// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/security/ReentrancyGuard.sol";
import "@starlay-protocol/interfaces/ILendingPool.sol";

import "./ILSTConvert.sol";

/// @title LendingPoolDepositConvertor Contract
/// @author Acala Developers
/// @notice Convert token to lToken by LendingPool.deposit of Starley.
contract LendingPoolDepositConvertor is ILSTConvert, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The Starlay LendingPool contract address.
    address public immutable lendingPool;

    /// @notice The token address to deposit.
    address public immutable depositToken;

    /// @notice Deploys LendingPoolDepositConvertor.
    /// @param lendingPoolAddr The Starlay LendingPool contract address.
    /// @param depositTokenAddr The token address to deposit.
    constructor(address lendingPoolAddr, address depositTokenAddr) {
        lendingPool = lendingPoolAddr;
        depositToken = depositTokenAddr;
    }

    /// @inheritdoc ILSTConvert
    function inputToken() external view override returns (address) {
        return depositToken;
    }

    /// @inheritdoc ILSTConvert
    function outputToken() public view override returns (address) {
        return ILendingPool(lendingPool).getReserveData(depositToken).lTokenAddress;
    }

    /// @inheritdoc ILSTConvert
    function convert(uint256 inputAmount) external override nonReentrant returns (uint256) {
        return _convert(inputAmount, msg.sender);
    }

    /// @inheritdoc ILSTConvert
    function convertTo(uint256 inputAmount, address receiver) external override nonReentrant returns (uint256) {
        require(receiver != address(0), "LendingPoolDepositConvertor: zero address not allowed");
        return _convert(inputAmount, receiver);
    }

    /// @notice Convert `inputAmount` token and send output token to `receiver`.
    /// @param inputAmount The input token amount to convert.
    /// @param receiver The receiver for the converted output token.
    /// @return outputAmount The output token amount.
    function _convert(uint256 inputAmount, address receiver) internal returns (uint256 outputAmount) {
        require(inputAmount != 0, "LendingPoolDepositConvertor: invalid input amount");
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), inputAmount);

        uint256 beforeOutputAmount = IERC20(outputToken()).balanceOf(address(this));
        IERC20(depositToken).safeApprove(lendingPool, inputAmount);
        ILendingPool(lendingPool).deposit(depositToken, inputAmount, address(this), 0);
        uint256 afterOutputAmount = IERC20(outputToken()).balanceOf(address(this));
        outputAmount = afterOutputAmount.sub(beforeOutputAmount);

        require(outputAmount > 0, "LendingPoolDepositConvertor: zero output");
        IERC20(outputToken()).safeTransfer(receiver, outputAmount);
    }
}
