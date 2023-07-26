// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@AcalaNetwork/predeploy-contracts/liquid-crowdloan/ILiquidCrowdloan.sol";
import "./MockToken.sol";

contract MockLiquidCrowdloan is ILiquidCrowdloan {
    using SafeMath for uint256;

    address public LCDOT;
    address private _redeemCurrency;
    uint256 public redeemExchangeRate;

    constructor(address lcdot, address redeemCurrency, uint256 rate) {
        LCDOT = lcdot;
        _redeemCurrency = redeemCurrency;
        redeemExchangeRate = rate;
    }

    function redeem(uint256 amount) external returns (uint256) {
        require(amount > 0, "MockLiquidCrowdloan: cannot redeem 0");

        uint256 redeemAmount = amount.mul(redeemExchangeRate).div(1e18);

        MockToken(LCDOT).burn(msg.sender, amount);
        IERC20(_redeemCurrency).transfer(msg.sender, redeemAmount);

        return redeemAmount;
    }

    function getRedeemCurrency() external view returns (address) {
        return _redeemCurrency;
    }
}
