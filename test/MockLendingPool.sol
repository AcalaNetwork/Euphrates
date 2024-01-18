// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "solmate/tokens/ERC20.sol";
import "@starlay-protocol/interfaces/ILendingPool.sol";
import "./MockToken.sol";

contract MockLendingPool is ILendingPool {
    mapping(address => address) internal _lTokens;

    function setLToken(address asset, address lToken) external {
        _lTokens[asset] = lToken;
    }

    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        MockToken(asset).transferFrom(msg.sender, address(this), amount);
        MockToken(_lTokens[asset]).mint(onBehalfOf, amount);
    }

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory) {
        return DataTypes.ReserveData({
            configuration: DataTypes.ReserveConfigurationMap({data: 0}),
            liquidityIndex: 0,
            variableBorrowIndex: 0,
            currentLiquidityRate: 0,
            currentVariableBorrowRate: 0,
            currentStableBorrowRate: 0,
            lastUpdateTimestamp: 0,
            lTokenAddress: _lTokens[asset],
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            id: 0
        });
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        revert("MockLendingPool: unimplement");
    }

    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external
    {
        revert("MockLendingPool: unimplement");
    }

    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256) {
        revert("MockLendingPool: unimplement");
    }

    function swapBorrowRateMode(address asset, uint256 rateMode) external {
        revert("MockLendingPool: unimplement");
    }

    function rebalanceStableBorrowRate(address asset, address user) external {
        revert("MockLendingPool: unimplement");
    }

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external {
        revert("MockLendingPool: unimplement");
    }

    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveLToken
    ) external {
        revert("MockLendingPool: unimplement");
    }

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external {
        revert("MockLendingPool: unimplement");
    }

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        revert("MockLendingPool: unimplement");
    }

    function initReserve(
        address reserve,
        address lTokenAddress,
        address stableDebtAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external {
        revert("MockLendingPool: unimplement");
    }

    function setReserveInterestRateStrategyAddress(address reserve, address rateStrategyAddress) external {
        revert("MockLendingPool: unimplement");
    }

    function setConfiguration(address reserve, uint256 configuration) external {
        revert("MockLendingPool: unimplement");
    }

    function getConfiguration(address asset) external view returns (DataTypes.ReserveConfigurationMap memory) {
        revert("MockLendingPool: unimplement");
    }

    function getUserConfiguration(address user) external view returns (DataTypes.UserConfigurationMap memory) {
        revert("MockLendingPool: unimplement");
    }

    function getReserveNormalizedIncome(address asset) external view returns (uint256) {
        revert("MockLendingPool: unimplement");
    }

    function getReserveNormalizedVariableDebt(address asset) external view returns (uint256) {
        revert("MockLendingPool: unimplement");
    }

    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromAfter,
        uint256 balanceToBefore
    ) external {
        revert("MockLendingPool: unimplement");
    }

    function getReservesList() external view returns (address[] memory) {
        revert("MockLendingPool: unimplement");
    }

    function getAddressesProvider() external view returns (ILendingPoolAddressesProvider) {
        revert("MockLendingPool: unimplement");
    }

    function setPause(bool val) external {
        revert("MockLendingPool: unimplement");
    }

    function paused() external view returns (bool) {
        revert("MockLendingPool: unimplement");
    }
}
