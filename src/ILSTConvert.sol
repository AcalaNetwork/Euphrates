// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";

interface ILSTConvert {
    function inputToken() external view returns (address);

    function outputToken() external view returns (address);

    function convertThreshold() external view returns (uint256);

    function convert(uint256 inputAmount) external returns (uint256);

    function convertTo(uint256 inputAmount, address receiver) external returns (uint256);
}
