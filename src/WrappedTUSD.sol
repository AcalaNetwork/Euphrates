// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/security/ReentrancyGuard.sol";
import "solmate/tokens/ERC20.sol";

import "./IWrappedStableAssetShare.sol";

/// @title WrappedTUSD Contract
/// @author Acala Developers
/// @notice To wrap TUSD, TUSD is the LP token of Taiga's StableAsset(USDCet-USDT) pool on Acala. The TUSD holders
/// can receive TUSD as the LP fee by claim. So WTUSD and TUSD do not maintain a 1:1 ratio.
contract WrappedTUSD is IWrappedStableAssetShare, ERC20, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The token address of TUSD.
    address public immutable tusd;

    /// @notice Deploys WTUSD token.
    /// @param tusdAddr The token address of TUSD.
    constructor(address tusdAddr) ERC20("Wrapped TUSD", "WTUSD", 6) {
        tusd = tusdAddr;
    }

    /// @inheritdoc IWrappedStableAssetShare
    function depositRate() public view returns (uint256) {
        uint256 tusdAmount = IERC20(tusd).balanceOf(address(this));
        uint256 wtusdAmount = totalSupply;

        if (wtusdAmount == 0 || tusdAmount == 0) {
            return 1e18;
        } else {
            return wtusdAmount.mul(1e18).div(tusdAmount);
        }
    }

    /// @inheritdoc IWrappedStableAssetShare
    function withdrawRate() public view returns (uint256) {
        uint256 tusdAmount = IERC20(tusd).balanceOf(address(this));
        uint256 wtusdAmount = totalSupply;

        if (wtusdAmount == 0) {
            return 0;
        } else {
            return tusdAmount.mul(1e18).div(wtusdAmount);
        }
    }

    /// @inheritdoc IWrappedStableAssetShare
    function deposit(uint256 tusdAmount) public returns (uint256) {
        uint256 wtusdAmount = tusdAmount.mul(depositRate()).div(1e18);
        require(wtusdAmount != 0, "WTUSD: invalid WTUSD amount");

        IERC20(tusd).safeTransferFrom(msg.sender, address(this), tusdAmount);
        _mint(msg.sender, wtusdAmount);

        emit Deposit(msg.sender, tusdAmount, wtusdAmount);
        return wtusdAmount;
    }

    /// @inheritdoc IWrappedStableAssetShare
    function withdraw(uint256 wtusdAmount) public returns (uint256) {
        require(balanceOf[msg.sender] >= wtusdAmount, "WTUSD: WTUSD not enough");
        uint256 tusdAmount = wtusdAmount.mul(withdrawRate()).div(1e18);
        require(tusdAmount != 0, "WTUSD: invalid TUSD amount");

        _burn(msg.sender, wtusdAmount);
        IERC20(tusd).safeTransfer(msg.sender, tusdAmount);

        emit Withdraw(msg.sender, wtusdAmount, tusdAmount);
        return tusdAmount;
    }
}
