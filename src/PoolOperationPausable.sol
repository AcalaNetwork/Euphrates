// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/// @title PoolOperationPausable Contract
/// @author Acala Developers
/// @notice You can add modifier to functions to pause/unpause user operation for each pool by inherit this contract.
/// @dev This contract does not define access control for functions, you should override these define
/// in the derived contract.
abstract contract PoolOperationPausable {
    /// @notice The user operation pause status of `poolId` pool updated.
    /// @param poolId The index of staking pool.
    /// @param operation The user operation.
    /// @param paused True is paused, false is unpaused.
    event OperationPauseStatusSet(uint256 poolId, Operation operation, bool paused);

    enum Operation {
        Stake,
        Unstake,
        ClaimRewards
    }

    /// @dev The pause status for user operation of pool.
    /// (poolId => (operation => paused))
    mapping(uint256 => mapping(Operation => bool)) internal _pausedPoolOperations;

    /// @dev Modifier to be added to corresponding function, if it is checked that a user operation is paused,
    /// revert the transaction.
    modifier poolOperationNotPaused(uint256 poolId, Operation operation) {
        require(
            pausedPoolOperations(poolId, operation) == false, "PoolOperationPausable: operation is paused for this pool"
        );
        _;
    }

    /// @notice Get the pause status of `operation` for `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param operation The user operation.
    /// @return Returns True means paused.
    function pausedPoolOperations(uint256 poolId, Operation operation) public view virtual returns (bool) {
        return _pausedPoolOperations[poolId][operation];
    }

    /// @notice Set the `paused` status of `operation` for `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param operation The user operation.
    /// @param paused The pause status.
    /// @dev you should override this function to define access control in the derived contract.
    function setPoolOperationPause(uint256 poolId, Operation operation, bool paused) public virtual {
        _pausedPoolOperations[poolId][operation] = paused;
        emit OperationPauseStatusSet(poolId, operation, paused);
    }
}
