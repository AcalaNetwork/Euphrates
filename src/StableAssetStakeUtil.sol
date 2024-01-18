// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "./IWrappedStableAssetShare.sol";
import "./IStaking.sol";

/// @title StableAssetStakeUtil Contract
/// @author Acala Developers
/// @notice Utilitity contract support batch these operation:
/// 1. mint StaleAsset LP token
/// 2. wrap LP token to Wrapped LP token
/// 3. stake Wrapped LP token to Euphrates pool
contract StableAssetStakeUtil {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The token address of Euphrates.
    IStakingTo public immutable euphrates;

    /// @notice The StableAsset predeploy contract address.
    IStableAsset public immutable stableAsset;

    /// @notice The Homa predeploy contract address.
    IHoma public immutable homa;

    /// @notice The LDOT token address.
    address public immutable ldot;

    /// @notice Deploys StableAssetStakeUtil contract.
    /// @param euphratesAddr The contract address of Euphrates.
    /// @param stableAssetAddr The contract address of StableAsset predeploy contract.
    /// @param homaAddr The contract address of Homa predeploy contract.
    /// @param ldotAddr The LDOT token address.
    constructor(address euphratesAddr, address stableAssetAddr, address homaAddr, address ldotAddr) {
        euphrates = IStakingTo(euphratesAddr);
        stableAsset = IStableAsset(stableAssetAddr);
        homa = IHoma(homaAddr);
        ldot = ldotAddr;
    }

    /// @notice Mint StalbeAsset LP token and stake it's wrapped token to Euphrates pool.
    /// @param stableAssetPoolId The id of StableAsset pool.
    /// @param assetsAmount The amounts of assets of StableAsset pool used to mint.
    /// @param stableAssetShareToken The LP token of StableAsset pool.
    /// @param wrappedShareToken The wrapper for StableAsset LP token.
    /// @param poolId The if of Euphrates pool.
    /// @return Returns (success).
    function mintAndStake(
        uint32 stableAssetPoolId,
        uint256[] memory assetsAmount,
        IERC20 stableAssetShareToken,
        IWrappedStableAssetShare wrappedShareToken,
        uint256 poolId
    ) public returns (bool) {
        // StableAsset check
        (bool valid, address[] memory assets) = stableAsset.getStableAssetPoolTokens(stableAssetPoolId);
        require(valid && assetsAmount.length == assets.length, "StableAssetStakeUtil: invalid stable asset pool");

        uint256[] memory paramAmounts = assetsAmount;
        // transfer assets from msg.sender
        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsAmount[i] != 0) {
                IERC20(assets[i]).safeTransferFrom(msg.sender, address(this), assetsAmount[i]);
            }
            // convert LDOT amount to rebased LDOT amount as the param
            // NOTE: the precision of Homa.getExchangeRate is 1e18
            if (assets[i] == ldot) {
                paramAmounts[i] = assetsAmount[i].mul(homa.getExchangeRate()).div(1e18);
            }
        }

        // StableAsset mint, no need to approve assets to stable-asset
        uint256 beforeStableAssetShareAmount = IERC20(stableAssetShareToken).balanceOf(address(this));
        // NOTE: allow max slippage here
        bool success = stableAsset.stableAssetMint(stableAssetPoolId, paramAmounts, 0);
        require(success, "StableAssetStakeUtil: stable-asset mint failed");
        uint256 afterStableAssetShareAmount = IERC20(stableAssetShareToken).balanceOf(address(this));
        uint256 mintedShareAmount = afterStableAssetShareAmount.sub(beforeStableAssetShareAmount);
        require(mintedShareAmount != 0, "StableAssetStakeUtil: zero minted share amount is not allowed");

        // wrap share token
        stableAssetShareToken.safeApprove(address(wrappedShareToken), mintedShareAmount);
        uint256 wrappedShareAmount = wrappedShareToken.deposit(mintedShareAmount);
        require(wrappedShareAmount != 0, "StableAssetStakeUtil: zero wrapped share amount is not allowed");

        // stake wrapped share token to Euphrates pool
        IERC20(address(wrappedShareToken)).safeApprove(address(euphrates), wrappedShareAmount);
        return euphrates.stakeTo(poolId, wrappedShareAmount, msg.sender);
    }

    /// @notice Wrap StalbeAsset LP token and stake to Euphrates pool.
    /// @param stableAssetShareToken The LP token of StableAsset pool.
    /// @param amount The amount of LP token.
    /// @param wrappedShareToken The wrapper for StableAsset LP token.
    /// @param poolId The id of Euphrates pool.
    /// @return Returns (success).
    function wrapAndStake(
        IERC20 stableAssetShareToken,
        uint256 amount,
        IWrappedStableAssetShare wrappedShareToken,
        uint256 poolId
    ) public returns (bool) {
        require(amount != 0, "StableAssetStakeUtil: zero share amount is not allowed");
        stableAssetShareToken.safeTransferFrom(msg.sender, address(this), amount);
        stableAssetShareToken.safeApprove(address(wrappedShareToken), amount);
        uint256 wrappedShareAmount = wrappedShareToken.deposit(amount);
        require(wrappedShareAmount != 0, "StableAssetStakeUtil: zero wrapped share amount is not allowed");

        // stake wrapped share token to Euphrates pool
        IERC20(address(wrappedShareToken)).safeApprove(address(euphrates), wrappedShareAmount);
        return euphrates.stakeTo(poolId, wrappedShareAmount, msg.sender);
    }
}
