// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/security/ReentrancyGuard.sol";
import "solmate/tokens/ERC20.sol";

/// @title IWTDOT Interface
/// @author Acala Developers
/// @notice You can use this integrate with WrappedTDOT.
interface IWTDOT {
    /// @notice Deposit TDOT to mint WTDOT.
    /// @param who The sender of the transaction.
    /// @param tdotAmount The TDOT amount to deposit.
    /// @param wtdotAmount The WTDOT amount received.
    event Deposit(address indexed who, uint256 tdotAmount, uint256 wtdotAmount);

    /// @notice Withdraw TDOT by burn WTDOT.
    /// @param who The sender of the transaction.
    /// @param wtdotAmount The WTDOT amount to burn.
    /// @param tdotAmount The TDOT amount received.
    event Withdraw(address indexed who, uint256 wtdotAmount, uint256 tdotAmount);

    /// @notice Get the deposit rate(the exchange rate for TDOT to WTDOT).
    /// @return Returns (exchangeRate). Deposit rate, 1e18 is 100%
    function depositRate() external view returns (uint256);

    /// @notice Get the withdraw rate(the exchange rate for WTDOT to TDOT).
    /// @return Returns (exchangeRate). Withdraw rate, 1e18 is 100%
    function withdrawRate() external view returns (uint256);

    /// @notice Deposit `tdotAmount` TDOT to mint WTDOT.
    /// @param tdotAmount The TDOT amount to deposit.
    /// @return Returns (wtdotAmount). The WTDOT amount received.
    function deposit(uint256 tdotAmount) external returns (uint256);

    /// @notice Withdraw TDOT by burn `wtdotAmount` WTDOT.
    /// @param wtdotAmount The WTDOT amount to burn.
    /// @return Returns (tdotAmount). The TDOT amount received.
    function withdraw(uint256 wtdotAmount) external returns (uint256);
}

/// @title WrappedTDOT Contract
/// @author Acala Developers
/// @notice To wrap TDOT, TDOT is the LP token of Taiga's StableAsset(DOT-LDOT) pool on Acala. The TDOT holders
/// can receive TDOT as the LP fee by claim. So WTDOT and DOT do not maintain a 1:1 ratio.
contract WrappedTDOT is IWTDOT, ERC20, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The token address of TDOT.
    address public immutable tdot;

    /// @notice Deploys WTDOT token.
    /// @param tdotAddr The token address of TDOT.
    constructor(address tdotAddr) ERC20("Wrapped TDOT", "WTDOT", 12) {
        tdot = tdotAddr;
    }

    /// @inheritdoc IWTDOT
    function depositRate() public view returns (uint256) {
        uint256 tdotAmount = IERC20(tdot).balanceOf(address(this));
        uint256 wtdotAmount = totalSupply;

        if (wtdotAmount == 0 || tdotAmount == 0) {
            return 1e18;
        } else {
            return wtdotAmount.mul(1e18).div(tdotAmount);
        }
    }

    /// @inheritdoc IWTDOT
    function withdrawRate() public view returns (uint256) {
        uint256 tdotAmount = IERC20(tdot).balanceOf(address(this));
        uint256 wtdotAmount = totalSupply;

        if (wtdotAmount == 0) {
            return 0;
        } else {
            return tdotAmount.mul(1e18).div(wtdotAmount);
        }
    }

    /// @inheritdoc IWTDOT
    function deposit(uint256 tdotAmount) public returns (uint256) {
        uint256 wtdotAmount = tdotAmount.mul(depositRate()).div(1e18);
        require(wtdotAmount != 0, "WTDOT: invalid WTDOT amount");

        IERC20(tdot).safeTransferFrom(msg.sender, address(this), tdotAmount);
        _mint(msg.sender, wtdotAmount);

        emit Deposit(msg.sender, tdotAmount, wtdotAmount);
        return wtdotAmount;
    }

    /// @inheritdoc IWTDOT
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
