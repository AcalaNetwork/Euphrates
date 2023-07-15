// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.17;

// import "forge-std/Test.sol";
// import "../src/Staking.sol";

// contract StakingTest is Test {
//     Staking public staking;

//     function setUp() public {
//         staking = new Staking();
//     }
// }

// // 使用 vm.expectRevert 来定位错误
// function test_CannotSubtract43() public {
//     vm.expectRevert(stdError.arithmeticError);
//     testNumber -= 43;
// }

// // 共享配置
// abstract contract HelperContract {
//     address constant IMPORTANT_ADDRESS = 0x543d...;
//     SomeContract someContract;
//     constructor() {...}
// }
// contract MyContractTest is Test, HelperContract {
//     function setUp() public {
//         someContract = new SomeContract(0, IMPORTANT_ADDRESS);
//         ...
//     }
// }

// // vm.prank 设定调用者地址
// function testFail_IncrementAsNotOwner() public {
//     vm.prank(address(0));
//     upOnly.increment();
// }

// // 合约中检查input 等直接影响合约状态的不严重错误， 使用require， 严重错误使用 revert ， 这样可读性更高
// function test_RevertWhen_CallerIsNotOwner() public {
//     vm.expectRevert(Unauthorized.selector);
//     vm.prank(address(0));
//     upOnly.increment();
// }

// // vm.expectEmit 检查 Event fileds， 最后一个bool值表示是否检查data相等
// // 触发event检查的写法，
// // vm.expectEmit 设置检查的范围
// // emit Event(...)设置期望的event
// // 在设置之后运行函数
// contract EmitContractTest is Test {
//     event Transfer(address indexed from, address indexed to, uint256 amount);

//     function test_ExpectEmit() public {
//         ExpectEmit emitter = new ExpectEmit();
//         // Check that topic 1, topic 2, and data are the same as the following emitted event.
//         // Checking topic 3 here doesn't matter, because `Transfer` only has 2 indexed topics.
//         vm.expectEmit(true, true, false, true);
//         // The event we expect
//         emit Transfer(address(this), address(1337), 1337);
//         // The event we get
//         emitter.t();
//     }

//     function test_ExpectEmit_DoNotCheckData() public {
//         ExpectEmit emitter = new ExpectEmit();
//         // Check topic 1 and topic 2, but do not check data
//         vm.expectEmit(true, true, false, false);
//         // The event we expect
//         emit Transfer(address(this), address(1337), 1338);
//         // The event we get
//         emitter.t();
//     }
// }
// contract ExpectEmit {
//     event Transfer(address indexed from, address indexed to, uint256 amount);

//     function t() public {
//         emit Transfer(msg.sender, address(1337), 1337);
//     }
// }

// // 读写storage的通用方法
// // find the variable `score` in the contract `game`
// // and change its value to 10
// stdstore
//     .target(address(game))
//     .sig(game.score.selector)
//     .checked_write(10);
