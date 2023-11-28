// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";
import "@AcalaNetwork/predeploy-contracts/liquid-crowdloan/ILiquidCrowdloan.sol";
import "../src/UpgradeableStakingLST.sol";
import "../src/UpgradeableStakingLSTV2.sol";

contract DeployUpgradeableStakingLSTOnAcala is Script {
    UpgradeableStakingLST implementationV1;
    UpgradeableStakingLSTV2 implementationV2;
    ITransparentUpgradeableProxy proxy;
    UpgradeableStakingLST wrappedProxyV1;
    ProxyAdmin admin;

    address public constant DOT = 0x0000000000000000000100000000000000000002;
    address public constant LCDOT = 0x000000000000000000040000000000000000000d;
    address public constant LDOT = 0x0000000000000000000100000000000000000003;
    address public constant TDOT = 0x0000000000000000000300000000000000000000;
    address public constant HOMA = 0x0000000000000000000000000000000000000805;
    address public constant STABLE_ASSET =
        0x0000000000000000000000000000000000000804;
    address public constant LIQUID_CROWDLOAN =
        0x000000000000000000000000000000000000080a;
    address public constant WTDOT = 0x000000000000000000000000000000000000080b; // TODO: did not existed, need config

    function run() public {
        // deploy admin contract as proxy admin
        admin = new ProxyAdmin();

        // deploy implementation contract
        implementationV1 = new UpgradeableStakingLST();

        // deploy proxy contract and fetch it as implementation, and specify admin as the owner of proxy admin
        proxy = ITransparentUpgradeableProxy(
            address(
                new TransparentUpgradeableProxy(
                    address(implementationV1),
                    address(admin),
                    ""
                )
            )
        );

        // wrap in ABI to support easier calls
        wrappedProxyV1 = UpgradeableStakingLST(address(proxy));

        // initialize
        implementationV1.initialize(
            DOT,
            LCDOT,
            LDOT,
            TDOT,
            HOMA,
            STABLE_ASSET,
            LIQUID_CROWDLOAN,
            WTDOT
        );
        assert(wrappedProxyV1.owner() == msg.sender);

        // new implementation and upgrade
        implementationV2 = new UpgradeableStakingLSTV2();
        admin.upgrade(proxy, address(implementationV2));
    }
}
