// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/security/ReentrancyGuard.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "@AcalaNetwork/predeploy-contracts/liquid-crowdloan/ILiquidCrowdloan.sol";

import "./ILSTConvert.sol";

contract LCDOT2LDOTConvertor is ILSTConvert, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable liquidCrowdloan;
    address public immutable homa;
    address public immutable lcdot;
    address public immutable dot;
    address public immutable ldot;

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

    function inputToken() external view override returns (address) {
        return lcdot;
    }

    function outputToken() external view override returns (address) {
        return ldot;
    }

    function convert(uint256 inputAmount) external override returns (uint256) {
        return _convert(inputAmount, msg.sender);
    }

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
