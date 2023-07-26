// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/UpgradeableStakingLSD.sol";
import "./MockHoma.sol";
import "./MockLiquidCrowdloan.sol";
import "./MockStableAsset.sol";
import "./MockToken.sol";

contract UpgradeableStakingLSDTest is Test {
    UpgradeableStakingLSD public staking;
    MockHoma public homa;
    MockStableAsset public stableAsset;
    MockLiquidCrowdloan public liquidCrowdloan;
    IERC20 public dot;
    IERC20 public ldot;
    IERC20 public lcdot;
    IERC20 public tdot;

    address public ADMIN = address(0x1111);
    address public ALICE = address(0x2222);

    function setUp() public {
        dot = IERC20(address(new MockToken("Acala DOT", "DOT", 1_000_000_000 ether)));
        lcdot = IERC20(address(new MockToken("Acala LcDOT", "LcDOT", 1_000_000_000 ether)));
        ldot = IERC20(address(new MockToken("Acala LDOT", "LDOT", 1_000_000_000 ether)));
        tdot = IERC20(address(new MockToken("Acala tDOT", "tDOT", 1_000_000_000 ether)));

        homa = new MockHoma(address(dot), address(ldot));
        stableAsset = new MockStableAsset(address(dot), address(ldot), address(tdot));
        liquidCrowdloan = new MockLiquidCrowdloan(address(lcdot), address(dot), 1e18);

        vm.prank(ADMIN);
        staking = new UpgradeableStakingLSD();
    }

    function test_initialize_works() public {
        assertEq(staking.owner(), address(0));
        assertEq(staking.DOT(), address(0));
        assertEq(staking.LCDOT(), address(0));
        assertEq(staking.LDOT(), address(0));
        assertEq(staking.TDOT(), address(0));
        assertEq(staking.HOMA(), address(0));
        assertEq(staking.STABLE_ASSET(), address(0));
        assertEq(staking.LIQUID_CROWDLOAN(), address(0));

        // check params
        vm.prank(ALICE);
        vm.expectRevert("LIQUID_CROWDLOAN address is zero");
        staking.initialize(
            address(dot), address(lcdot), address(ldot), address(tdot), address(homa), address(stableAsset), address(0)
        );

        // check initialize() has override and it will not do initialization
        vm.prank(ALICE);
        staking.initialize();
        assertEq(staking.owner(), address(0));
        vm.prank(ADMIN);
        staking.initialize();
        assertEq(staking.owner(), address(0));

        // anyone can initialize staking contract
        vm.prank(ALICE);
        staking.initialize(
            address(dot),
            address(lcdot),
            address(ldot),
            address(tdot),
            address(homa),
            address(stableAsset),
            address(liquidCrowdloan)
        );
        assertEq(staking.owner(), ALICE);
        assertEq(staking.DOT(), address(dot));
        assertEq(staking.LCDOT(), address(lcdot));
        assertEq(staking.LDOT(), address(ldot));
        assertEq(staking.TDOT(), address(tdot));
        assertEq(staking.HOMA(), address(homa));
        assertEq(staking.STABLE_ASSET(), address(stableAsset));
        assertEq(staking.LIQUID_CROWDLOAN(), address(liquidCrowdloan));

        // initialize cannot be called twice
        vm.prank(ADMIN);
        vm.expectRevert("Initializable: contract is already initialized");
        staking.initialize(
            address(dot),
            address(lcdot),
            address(ldot),
            address(tdot),
            address(homa),
            address(stableAsset),
            address(liquidCrowdloan)
        );
    }
}
