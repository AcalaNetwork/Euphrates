// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/UpgradeableStakingCommon.sol";

contract DeployStakingCommon is Script {
    UpgradeableStakingCommon implementationV1;
    TransparentUpgradeableProxy proxy;
    UpgradeableStakingCommon wrappedProxyV1;
    ProxyAdmin admin;

    function run() public {
        // deploy admin contract as proxy admin
        admin = new ProxyAdmin();

        // deploy implementation contract
        implementationV1 = new UpgradeableStakingCommon();

        // deploy proxy contract and fetch it as implementation, and specify admin as the owner of proxy admin
        proxy = new TransparentUpgradeableProxy(address(implementationV1), address(admin), "");

        // wrap in ABI to support easier calls
        wrappedProxyV1 = UpgradeableStakingCommon(address(proxy));
        assert(wrappedProxyV1.owner() == msg.sender);

        // initialize
        wrappedProxyV1.initialize();
        assert(wrappedProxyV1.owner() == msg.sender);

        // new implementation and upgrade
        // UpgradeableStakingCommonV2 implementationV2 = new UpgradeableStakingCommonV2();
        // admin.upgrade(proxy, address(implementationV2));
    }
}
