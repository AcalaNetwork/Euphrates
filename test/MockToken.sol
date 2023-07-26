// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "solmate/tokens/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initalAmount) ERC20(name, symbol, 18) {
        _mint(msg.sender, initalAmount);
    }

    function forceTransfer(address from, address to, uint256 amount) external {
        _burn(from, amount);
        _mint(to, amount);
    }

    function mint(address who, uint256 amount) external {
        _mint(who, amount);
    }

    function burn(address who, uint256 amount) external {
        _burn(who, amount);
    }
}
