// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./ILiquidCrowdloan.sol";

/// mock liquid crowdloan precompile contract interface
contract MockLiquidCrowdloan is ILiquidCrowdloan {
    address public dot;

    constructor(address _dot) {
        dot = _dot;
    }

    function redeem(uint256 amount) external returns (bool) {
        require(amount > 0, "cannot redeem 0");

        IERC20(dot).transfer(msg.sender, amount);

        emit Redeem(msg.sender, amount);
        return true;
    }
}
