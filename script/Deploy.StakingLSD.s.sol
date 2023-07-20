// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "@openzeppelin-contracts/access/Ownable.sol";
import "../src/StakingLSD.sol";

contract DeployStakingLSDOnMandalaTC9 is Script {
    StakingLSD staking;

    address public constant DOT = 0x0000000000000000000100000000000000000002;
    address public constant LCDOT = 0x000000000000000000040000000000000000000d;
    address public constant LDOT = 0x0000000000000000000100000000000000000003;
    address public constant TDOT = 0x0000000000000000000300000000000000000000;
    address public constant HOMA = 0x0000000000000000000000000000000000000805;
    address public constant STABLE_ASSET = 0x0000000000000000000000000000000000000804;
    address public constant LIQUID_CROWDLOAN = 0x0000000000000000000100000000000000000018; // TODO: did not existed, need config

    function run() public {
        // deploy implementation contract
        staking = new StakingLSD(
            DOT, 
            LCDOT,
            LDOT,
            TDOT,
            HOMA,
            STABLE_ASSET,
            LIQUID_CROWDLOAN
        );
        assert(staking.owner() == msg.sender);
    }
}
