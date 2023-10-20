// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./IStaking.sol";
import "./UpgradeableStakingLST.sol";
import "./WrappedTDOT.sol";

/// @title IStakingTo Interface
/// @author Acala Developers
/// @notice You can use this integrate Acala LST staking into your contract.
interface IStakingTo is IStaking {
    /// @notice Stake share to other.
    /// @param poolId The index of staking pool.
    /// @param amount The share amount to stake.
    /// @param receiver The share receiver.
    /// @return Returns (success).
    function stakeTo(uint256 poolId, uint256 amount, address receiver) external returns (bool);
}

/// @title UpgradeableStakingLSTV2 Contract
/// @author Acala Developers
/// @notice V2 version for UpgradeableStakingLST, support stake share to other.
contract UpgradeableStakingLSTV2 is UpgradeableStakingLST, IStakingTo {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @inheritdoc IStakingTo
    function stakeTo(uint256 poolId, uint256 amount, address receiver)
        public
        virtual
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        updateRewards(poolId, receiver)
        nonReentrant
        returns (bool)
    {
        require(receiver != address(0), "invalid receiver");

        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");

        uint256 addedShare;
        ConvertInfo memory convertInfo = convertInfos(poolId);
        if (address(convertInfo.convertedShareType) != address(0)) {
            // if pool has converted, transfer the before share token to this firstly
            shareType.safeTransferFrom(msg.sender, address(this), amount);

            uint256 convertedAmount;
            if (address(shareType) == LCDOT && address(convertInfo.convertedShareType) == LDOT) {
                convertedAmount = _convertLCDOT2LDOT(amount);
            } else if (address(shareType) == LCDOT && address(convertInfo.convertedShareType) == TDOT) {
                convertedAmount = _convertLCDOT2TDOT(amount);
            } else if (address(shareType) == DOT && address(convertInfo.convertedShareType) == LDOT) {
                convertedAmount = _convertDOT2LDOT(amount);
            } else if (address(shareType) == DOT && address(convertInfo.convertedShareType) == TDOT) {
                convertedAmount = _convertDOT2TDOT(amount);
            } else if (address(shareType) == LCDOT && address(convertInfo.convertedShareType) == WTDOT) {
                uint256 tdotAmount = _convertLCDOT2TDOT(amount);
                convertedAmount = _convertTDOT2WTDOT(tdotAmount);
            } else if (address(shareType) == DOT && address(convertInfo.convertedShareType) == WTDOT) {
                uint256 tdotAmount = _convertDOT2TDOT(amount);
                convertedAmount = _convertTDOT2WTDOT(tdotAmount);
            } else {
                revert("unsupported converted share token");
            }

            // must convert the share amount according to the exchange rate of converted pool
            addedShare = convertedAmount.mul(1e18).div(convertInfo.convertedExchangeRate);
        } else if (address(shareType) == WTDOT) {
            // transfer TDOT to this, convert it to WTDOT and stake it
            IERC20(TDOT).safeTransferFrom(msg.sender, address(this), amount);
            addedShare = _convertTDOT2WTDOT(amount);
        } else {
            // if pool hasn't converted, stake it directly
            shareType.safeTransferFrom(msg.sender, address(this), amount);
            addedShare = amount;
        }

        require(addedShare > 0, "cannot stake 0");
        _totalShares[poolId] = _totalShares[poolId].add(addedShare);
        _shares[poolId][receiver] = _shares[poolId][receiver].add(addedShare);

        emit Stake(receiver, poolId, addedShare);

        return true;
    }
}
