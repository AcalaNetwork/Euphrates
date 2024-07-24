// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@AcalaNetwork/predeploy-contracts/dex/IDEX.sol";
import "./MockToken.sol";

contract MockDEX is IDEX {
    using SafeMath for uint256;

    address public immutable TOKEN_0;
    address public immutable TOKEN_1;
    address public immutable LP_TOKEN;
    uint256 public pool0;
    uint256 public pool1;

    constructor(address token0, address token1, address lpToken) {
        TOKEN_0 = token0;
        TOKEN_1 = token1;
        LP_TOKEN = lpToken;
    }

    function getLiquidityPool(address tokenA, address tokenB) external view returns (uint256, uint256) {
        if (tokenA == TOKEN_0 && tokenB == TOKEN_1) {
            return (pool0, pool1);
        } else if (tokenB == TOKEN_0 && tokenA == TOKEN_1) {
            return (pool1, pool0);
        } else {
            return (0, 0);
        }
    }

    function getLiquidityTokenAddress(address tokenA, address tokenB) external view returns (address) {
        if ((tokenA == TOKEN_0 && tokenB == TOKEN_1) || (tokenB == TOKEN_0 && tokenA == TOKEN_1)) {
            return LP_TOKEN;
        } else {
            return address(0);
        }
    }

    function getSwapTargetAmount(address[] calldata path, uint256 supplyAmount) public view returns (uint256) {
        require(path.length >= 2, "MockDEX: invalid swap path");
        uint256 invariants = pool0.mul(pool1);
        if (path[0] == TOKEN_0 && path[path.length - 1] == TOKEN_1) {
            return pool1.sub(invariants.div(pool0.add(supplyAmount)));
        } else if (path[0] == TOKEN_1 && path[path.length - 1] == TOKEN_0) {
            return pool0.sub(invariants.div(pool1.add(supplyAmount)));
        } else {
            return 0;
        }
    }

    function getSwapSupplyAmount(address[] calldata path, uint256 targetAmount) public view returns (uint256) {
        require(path.length >= 2, "MockDEX: invalid swap path");
        uint256 invariants = pool0.mul(pool1);
        if (path[0] == TOKEN_0 && path[path.length - 1] == TOKEN_1) {
            return invariants.div(pool1.sub(targetAmount)).sub(pool0);
        } else if (path[0] == TOKEN_1 && path[path.length - 1] == TOKEN_0) {
            return invariants.div(pool0.sub(targetAmount)).sub(pool1);
        } else {
            return 0;
        }
    }

    function swapWithExactSupply(address[] calldata path, uint256 supplyAmount, uint256 minTargetAmount)
        external
        returns (bool)
    {
        require(path.length >= 2, "MockDEX: invalid swap path");

        uint256 targetAmount = getSwapTargetAmount(path, supplyAmount);
        require(targetAmount != 0 && targetAmount >= minTargetAmount, "MockDEX: swap failed");

        if (path[0] == TOKEN_0 && path[path.length - 1] == TOKEN_1) {
            MockToken(TOKEN_0).forceTransfer(msg.sender, address(this), supplyAmount);
            MockToken(TOKEN_1).forceTransfer(address(this), msg.sender, targetAmount);
            pool0 = pool0.add(supplyAmount);
            pool1 = pool1.sub(targetAmount);
        } else if (path[0] == TOKEN_1 && path[path.length - 1] == TOKEN_0) {
            MockToken(TOKEN_1).forceTransfer(msg.sender, address(this), supplyAmount);
            MockToken(TOKEN_0).forceTransfer(address(this), msg.sender, targetAmount);
            pool1 = pool1.add(supplyAmount);
            pool0 = pool0.sub(targetAmount);
        }

        return true;
    }

    function swapWithExactTarget(address[] calldata path, uint256 targetAmount, uint256 maxSupplyAmount)
        external
        returns (bool)
    {
        require(path.length >= 2, "MockDEX: invalid swap path");

        uint256 supplyAmount = getSwapSupplyAmount(path, targetAmount);
        require(supplyAmount != 0 && supplyAmount <= maxSupplyAmount, "MockDEX: swap failed");

        if (path[0] == TOKEN_0 && path[path.length - 1] == TOKEN_1) {
            MockToken(TOKEN_0).forceTransfer(msg.sender, address(this), supplyAmount);
            MockToken(TOKEN_1).forceTransfer(address(this), msg.sender, targetAmount);
            pool0 = pool0.add(supplyAmount);
            pool1 = pool1.sub(targetAmount);
        } else if (path[0] == TOKEN_1 && path[path.length - 1] == TOKEN_0) {
            MockToken(TOKEN_1).forceTransfer(msg.sender, address(this), supplyAmount);
            MockToken(TOKEN_0).forceTransfer(address(this), msg.sender, targetAmount);
            pool1 = pool1.add(supplyAmount);
            pool0 = pool0.sub(targetAmount);
        }

        return true;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 maxAmountA,
        uint256 maxAmountB,
        uint256 minShareIncrement
    ) external returns (bool) {
        require(maxAmountA != 0 && maxAmountB != 0, "MockDEX: invalid add liquidity amount");

        if (tokenA == TOKEN_0 && tokenB == TOKEN_1) {
            if (pool0 == 0 || pool1 == 0) {
                require(maxAmountA >= minShareIncrement, "MockDEX: add liquidity failed");
                MockToken(TOKEN_0).forceTransfer(msg.sender, address(this), maxAmountA);
                MockToken(TOKEN_1).forceTransfer(msg.sender, address(this), maxAmountB);
                pool0 = pool0.add(maxAmountA);
                pool1 = pool1.add(maxAmountB);
                MockToken(LP_TOKEN).mint(msg.sender, maxAmountA);
            } else {
                uint256 actualA;
                uint256 actualB;

                if (pool1.mul(maxAmountA).div(pool0) <= maxAmountB) {
                    actualA = maxAmountA;
                    actualB = pool1.mul(maxAmountA).div(pool0);
                } else {
                    actualA = pool0.mul(maxAmountB).div(pool1);
                    actualB = maxAmountB;
                }

                uint256 shareIncrement = actualA.mul(MockToken(LP_TOKEN).totalSupply()).div(pool0);
                require(
                    actualA != 0 && actualB != 0 && shareIncrement != 0 && shareIncrement >= minShareIncrement,
                    "MockDEX: add liquidity failed"
                );

                MockToken(TOKEN_0).forceTransfer(msg.sender, address(this), actualA);
                MockToken(TOKEN_1).forceTransfer(msg.sender, address(this), actualB);
                pool0 = pool0.add(actualA);
                pool1 = pool1.add(actualB);
                MockToken(LP_TOKEN).mint(msg.sender, shareIncrement);
            }
        } else if (tokenB == TOKEN_0 && tokenA == TOKEN_1) {
            if (pool0 == 0 || pool1 == 0) {
                require(maxAmountB >= minShareIncrement, "MockDEX: add liquidity failed");
                MockToken(TOKEN_0).forceTransfer(msg.sender, address(this), maxAmountB);
                MockToken(TOKEN_1).forceTransfer(msg.sender, address(this), maxAmountA);
                pool0 = pool0.add(maxAmountB);
                pool1 = pool1.add(maxAmountA);
                MockToken(LP_TOKEN).mint(msg.sender, maxAmountB);
            } else {
                uint256 actualA;
                uint256 actualB;

                if (pool0.mul(maxAmountA).div(pool1) <= maxAmountB) {
                    actualA = maxAmountA;
                    actualB = pool0.mul(maxAmountA).div(pool1);
                } else {
                    actualA = pool1.mul(maxAmountB).div(pool0);
                    actualB = maxAmountB;
                }

                uint256 shareIncrement = actualB.mul(MockToken(LP_TOKEN).totalSupply()).div(pool0);
                require(
                    actualA != 0 && actualB != 0 && shareIncrement != 0 && shareIncrement >= minShareIncrement,
                    "MockDEX: add liquidity failed"
                );

                MockToken(TOKEN_0).forceTransfer(msg.sender, address(this), actualB);
                MockToken(TOKEN_1).forceTransfer(msg.sender, address(this), actualA);
                pool0 = pool0.add(actualB);
                pool1 = pool1.add(actualA);
                MockToken(LP_TOKEN).mint(msg.sender, shareIncrement);
            }
        } else {
            revert("MockDEX: invalid pool");
        }

        return true;
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 removeShare,
        uint256 minWithdrawnA,
        uint256 minWithdrawnB
    ) external returns (bool) {
        revert("MockHoma: unimplement");
    }
}
