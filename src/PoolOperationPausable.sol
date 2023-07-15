// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

abstract contract PoolOperationPausable {
    event PoolOperationSet(uint256 poolId, Operation operation, bool prohibited);

    enum Operation {
        Stake,
        Unstake,
        ClaimRewards
    }

    mapping(uint256 => mapping(Operation => bool)) internal _pausedPoolOperations;

    modifier poolOperationNotPaused(uint256 poolId, Operation operation) {
        require(pausedPoolOperations(poolId, operation) == false, "The pool prohibited this operation.");
        _;
    }

    function pausedPoolOperations(uint256 poolId, Operation operation) public view virtual returns (bool) {
        return _pausedPoolOperations[poolId][operation];
    }

    function setPoolOperationPause(uint256 poolId, Operation operation, bool paused) public virtual {
        _pausedPoolOperations[poolId][operation] = paused;
        emit PoolOperationSet(poolId, operation, paused);
    }
}
