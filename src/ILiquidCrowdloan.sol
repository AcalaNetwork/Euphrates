// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/// mock liquid crowdloan precompile contract interface
interface ILiquidCrowdloan {
    event Redeem(address indexed redeemer, uint256 amount);

    function redeem(uint256 amount) external returns (bool);
}
