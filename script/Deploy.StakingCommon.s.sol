// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "@openzeppelin-contracts/access/Ownable.sol";
import "../src/StakingCommon.sol";

contract DeployStakingCommon is Script {
    StakingCommon staking;

    function run() public {
        // deploy implementation contract
        staking = new StakingCommon();
        assert(staking.owner() == msg.sender);
    }
}
