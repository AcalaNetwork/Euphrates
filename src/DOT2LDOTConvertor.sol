// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/security/ReentrancyGuard.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";

import "./ILSTConvert.sol";

/// @title DOT2LDOTConvertor Contract
/// @author Acala Developers
/// @notice Convert DOT to LDOT by Homa protocal of Acala.
contract DOT2LDOTConvertor is ILSTConvert, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The Homa predeployed contract of Acala.
    address public immutable homa;

    /// @notice The token address of DOT.
    address public immutable dot;

    /// @notice The token address of LDOT.
    address public immutable ldot;

    /// @notice Deploys DOT2LDOTConvertor.
    /// @param homaAddr The predeployed Homa contract of Acala.
    /// @param dotAddr The token address of DOT.
    /// @param ldotAddr The token address of LDOT.
    constructor(address homaAddr, address dotAddr, address ldotAddr) {
        homa = homaAddr;
        dot = dotAddr;
        ldot = ldotAddr;
    }

    /// @inheritdoc ILSTConvert
    function inputToken() external view override returns (address) {
        return dot;
    }

    /// @inheritdoc ILSTConvert
    function outputToken() external view override returns (address) {
        return ldot;
    }

    /// @inheritdoc ILSTConvert
    function convert(
        uint256 inputAmount
    ) external override nonReentrant returns (uint256) {
        return _convert(inputAmount, msg.sender);
    }

    /// @inheritdoc ILSTConvert
    function convertTo(
        uint256 inputAmount,
        address receiver
    ) external override nonReentrant returns (uint256) {
        require(
            receiver != address(0),
            "DOT2LDOTConvertor: zero address not allowed"
        );
        return _convert(inputAmount, receiver);
    }

    /// @notice Convert `inputAmount` token and send output token to `receiver`.
    /// @param inputAmount The input token amount to convert.
    /// @param receiver The receiver for the converted output token.
    /// @return outputAmount The output token amount.
    function _convert(
        uint256 inputAmount,
        address receiver
    ) internal returns (uint256 outputAmount) {
        require(inputAmount != 0, "DOT2LDOTConvertor: invalid input amount");
        IERC20(dot).safeTransferFrom(msg.sender, address(this), inputAmount);

        uint256 beforeLdotAmount = IERC20(ldot).balanceOf(address(this));
        bool success = IHoma(homa).mint(inputAmount);
        require(success, "DOT2LDOTConvertor: homa mint failed");
        uint256 afterLdotAmount = IERC20(ldot).balanceOf(address(this));
        outputAmount = afterLdotAmount.sub(beforeLdotAmount);

        require(outputAmount > 0, "DOT2LDOTConvertor: zero output");
        IERC20(ldot).safeTransfer(receiver, outputAmount);
    }
}
