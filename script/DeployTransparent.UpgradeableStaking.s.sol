// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/UpgradeableStaking.sol";

contract DeployTransparent is Script {
    UpradeableStaking implementationV1;
    TransparentUpgradeableProxy proxy;
    UpradeableStaking wrappedProxyV1;
    ProxyAdmin admin;

    function run() public {
        admin = new ProxyAdmin();

        implementationV1 = new UpradeableStaking();

        // deploy proxy contract and point it to implementation
        proxy = new TransparentUpgradeableProxy(address(implementationV1), address(admin), "");

        // wrap in ABI to support easier calls
        wrappedProxyV1 = UpradeableStaking(address(proxy));
        wrappedProxyV1.initialize();

        // new implementation
        // UpradeableStakingV2 implementationV2 = new UpradeableStakingV2();
        // admin.upgrade(proxy, address(implementationV2));
    }
}
