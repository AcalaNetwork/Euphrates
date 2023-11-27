// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";
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

    /// @notice Deploys StableAssetStakeUtil contract.
    /// @param euphratesAddr The contract address of Euphrates.
    /// @param stableAssetAddress The contract address of StableAsset predeploy contract.
    constructor(address euphratesAddr, address stableAssetAddress) {
        euphrates = IStakingTo(euphratesAddr);
        stableAsset = IStableAsset(stableAssetAddress);
    }

    /// @notice Mint StalbeAsset LP token and stake it's wrapped token to Euphrates pool.
    /// @param stableAssetPoolId The id of StableAsset pool.
    /// @param assetsAmount The amounts of assets of StableAsset pool used to mint.
    /// @param stableAssetShareToken The LP token of StableAsset pool.
    /// @param wrappedShareToken The wrapper for StableAsset LP token.
    /// @param poolId The if of Euphrates pool.
    /// @return Returns (success).
    /// @dev it's not compitable with StableAsset TDOT pool becuase of the assets amount of LDOT is rebased.
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

        // transfer assets from msg.sender
        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsAmount[i] != 0) {
                IERC20(assets[i]).safeTransferFrom(msg.sender, address(this), assetsAmount[i]);
            }
        }

        // StableAsset mint, no need to approve assets to stable-asset
        uint256 beforeStableAssetShareAmount = IERC20(stableAssetShareToken).balanceOf(address(this));

        // NOTE: use assetsAmount as the params, it cannot used to StableAsset TDOT pool because TDOT pool mint params amount is rebased!
        bool success = stableAsset.stableAssetMint(stableAssetPoolId, assetsAmount, 0);
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
}
