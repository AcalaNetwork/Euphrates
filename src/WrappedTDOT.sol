// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "solmate/tokens/ERC20.sol";

interface IWTDOT {
    event Deposit(address indexed who, uint256 tdotAmount, uint256 wtdotAmount);
    event Withdraw(address indexed who, uint256 wtdotAmount, uint256 tdotAmount);

    function depositRate() external view returns (uint256);
    function withdrawRate() external view returns (uint256);
    function deposit(uint256 tdotAmount) external returns (uint256);
    function withdraw(uint256 wtdotAmount) external returns (uint256);
    function getRedeemCurrency() external view returns (address);
}

contract WrappedTDOT is IWTDOT, ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable tdot;

    constructor(address tdotAddr) ERC20("Wrapped TDOT", "WTDOT", 12) {
        tdot = tdotAddr;
    }

    function getRedeemCurrency() external view returns (address) {
        return tdot;
    }

    // tdot 对 wtdot 的 exchangerate
    function depositRate() public view returns (uint256) {
        uint256 tdotAmount = IERC20(tdot).balanceOf(address(this));
        uint256 wtdotAmount = this.totalSupply();

        if (wtdotAmount == 0) {
            return 1e18;
        } else if (tdotAmount == 0) {
            return 0;
        } else {
            return wtdotAmount.mul(1e18).div(tdotAmount);
        }
    }

    // wtdot 对 tdot 的 exchangerate
    function withdrawRate() public view returns (uint256) {
        uint256 tdotAmount = IERC20(tdot).balanceOf(address(this));
        uint256 wtdotAmount = totalSupply;

        if (wtdotAmount == 0) {
            return 0;
        } else {
            return tdotAmount.mul(1e18).div(wtdotAmount);
        }
    }

    function deposit(uint256 tdotAmount) public returns (uint256) {
        uint256 wtdotAmount = tdotAmount.mul(depositRate()).div(1e18);
        require(wtdotAmount != 0, "WTDOT: invalid WTDOT amount");

        IERC20(tdot).safeTransferFrom(msg.sender, address(this), tdotAmount);
        _mint(msg.sender, wtdotAmount);

        emit Deposit(msg.sender, tdotAmount, wtdotAmount);
        return wtdotAmount;
    }

    function withdraw(uint256 wtdotAmount) public returns (uint256) {
        require(balanceOf[msg.sender] >= wtdotAmount, "WTDOT: WTDOT not enough");
        uint256 tdotAmount = wtdotAmount.mul(withdrawRate()).div(1e18);
        require(tdotAmount != 0, "WTDOT: invalid TDOT amount");

        _burn(msg.sender, wtdotAmount);
        IERC20(tdot).safeTransfer(msg.sender, tdotAmount);

        emit Withdraw(msg.sender, wtdotAmount, tdotAmount);
        return tdotAmount;
    }
}
