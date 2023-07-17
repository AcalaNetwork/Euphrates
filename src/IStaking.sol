// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

interface IStaking {
    event ClaimReward(address indexed account, uint256 poolId, IERC20 indexed rewardType, uint256 amount);
    event Unstake(address indexed account, uint256 poolId, uint256 amount);
    event Stake(address indexed account, uint256 poolId, uint256 amount);

    function shareTypes(uint256 poolId) external view returns (IERC20);
    function totalShares(uint256 poolId) external view returns (uint256);
    function rewardTypes(uint256 poolId) external view returns (IERC20[] memory);
    function shares(uint256 poolId, address account) external view returns (uint256);
    function earned(uint256 poolId, address account, IERC20 rewardType) external view returns (uint256);

    function stake(uint256 poolId, uint256 amount) external returns (bool);
    function unstake(uint256 poolId, uint256 amount) external returns (bool);
    function claimRewards(uint256 poolId) external returns (bool);
    function exit(uint256 poolId) external returns (bool);
}
