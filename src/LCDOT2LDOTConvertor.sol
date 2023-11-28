// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/security/ReentrancyGuard.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "@AcalaNetwork/predeploy-contracts/liquid-crowdloan/ILiquidCrowdloan.sol";

import "./ILSTConvert.sol";

/// @title LCDOT2LDOTConvertor Contract
/// @author Acala Developers
/// @notice Convert LCDOT to LDOT by LiquidCrowdloan and Homa protocal of Acala.
contract LCDOT2LDOTConvertor is ILSTConvert, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The LiquidCrowdloan predeployed contract of Acala.
    address public immutable liquidCrowdloan;

    /// @notice The Homa predeployed contract of Acala.
    address public immutable homa;

    /// @notice The token address of LCDOT.
    address public immutable lcdot;

    /// @notice The token address of DOT.
    address public immutable dot;

    /// @notice The token address of LDOT.
    address public immutable ldot;

    /// @notice Deploys LCDOT2LDOTConvertor.
    /// @param liquidCrowdloanAddr The predeployed LiquidCrowdloan contract of Acala.
    /// @param homaAddr The predeployed Homa contract of Acala.
    /// @param lcdotAddr The token address of LCDOT.
    /// @param dotAddr The token address of DOT.
    /// @param ldotAddr The token address of LDOT.
    constructor(
        address liquidCrowdloanAddr,
        address homaAddr,
        address lcdotAddr,
        address dotAddr,
        address ldotAddr
    ) {
        liquidCrowdloan = liquidCrowdloanAddr;
        homa = homaAddr;
        lcdot = lcdotAddr;
        dot = dotAddr;
        ldot = ldotAddr;
    }

    /// @inheritdoc ILSTConvert
    function inputToken() external view override returns (address) {
        return lcdot;
    }

    /// @inheritdoc ILSTConvert
    function outputToken() external view override returns (address) {
        return ldot;
    }

    /// @inheritdoc ILSTConvert
    function convert(uint256 inputAmount) external override returns (uint256) {
        return _convert(inputAmount, msg.sender);
    }

    /// @inheritdoc ILSTConvert
    function convertTo(
        uint256 inputAmount,
        address receiver
    ) external override returns (uint256) {
        require(
            receiver != address(0),
            "LCDOT2LDOTConvertor: zero address not allowed"
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
        require(inputAmount > 0, "LCDOT2LDOTConvertor: invalid input amount");
        IERC20(lcdot).safeTransferFrom(msg.sender, address(this), inputAmount);

        address redeemCurrency = ILiquidCrowdloan(liquidCrowdloan)
            .getRedeemCurrency();
        uint256 redeemedAmount = ILiquidCrowdloan(liquidCrowdloan).redeem(
            inputAmount
        );

        if (redeemCurrency == ldot) {
            outputAmount = redeemedAmount;
        } else if (redeemCurrency == dot) {
            uint256 beforeLdotAmount = IERC20(ldot).balanceOf(address(this));
            bool success = IHoma(homa).mint(redeemedAmount);
            require(success, "LCDOT2LDOTConvertor: homa mint failed");
            uint256 afterLdotAmount = IERC20(ldot).balanceOf(address(this));
            outputAmount = afterLdotAmount.sub(beforeLdotAmount);
        } else {
            revert("LCDOT2LDOTConvertor: unsupported convert");
        }

        require(outputAmount > 0, "LCDOT2LDOTConvertor: zero output");
        IERC20(ldot).safeTransfer(receiver, outputAmount);
    }
}
