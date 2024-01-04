// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";
import "@AcalaNetwork/predeploy-contracts/liquid-crowdloan/ILiquidCrowdloan.sol";
import "./UpgradeableStakingLST.sol";
import "./ILSTConvert.sol";
import "./IStaking.sol";

/// @title UpgradeableStakingLSTV2 Contract
/// @author Acala Developers
/// @notice This staking contract can convert the share token to it's LST. It just support LcDOT token on Acala.
/// @dev After pool's share is converted into its LST token, this pool can be staked with LST token and before token both.
/// This version conforms to the specification for upgradeable contracts.
contract UpgradeableStakingLSTV2 is UpgradeableStakingLST, IStakingTo {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @dev The LST convertor of pool.
    /// (poolId => ILSTConvert)
    mapping(uint256 => ILSTConvert) private _poolConvertors;

    /// @notice Get the LST convertor of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns convertor address.
    function poolConvertors(uint256 poolId) public view returns (ILSTConvert) {
        return _poolConvertors[poolId];
    }

    /// @notice Reset the `convertor` as the convertor of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param convertor The LST convertor.
    function resetPoolConvertor(uint256 poolId, ILSTConvert convertor) public onlyOwner whenNotPaused {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");
        IERC20 convertedShareTypes = convertInfos(poolId).convertedShareType;
        require(address(convertedShareTypes) != address(0), "pool must be already converted");

        require(
            convertor.inputToken() == address(shareType) && convertor.outputToken() == address(convertedShareTypes),
            "convertor is not matched"
        );

        _poolConvertors[poolId] = convertor;
    }

    /// @notice convert the share token of ‘poolId’ pool to LST token by `convertType`.
    /// @param poolId The index of staking pool.
    /// @param convertType The convert type.
    /// @dev override to depracate it.
    function convertLSTPool(uint256 poolId, ConvertType convertType)
        external
        virtual
        override
        onlyOwner
        whenNotPaused
    {
        revert("deprecated");
    }

    /// @notice convert the share token of ‘poolId’ pool to LST token by `convertor`.
    /// @param poolId The index of staking pool.
    /// @param convertor The convert contract address.
    function convertLSTPool(uint256 poolId, ILSTConvert convertor) external virtual onlyOwner whenNotPaused {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");
        ConvertInfo storage convert = _convertInfos[poolId];
        require(address(convert.convertedShareType) == address(0), "already converted");

        uint256 amount = totalShares(poolId);
        require(amount > 0, "pool is empty");

        require(convertor.inputToken() == address(shareType), "convertor is not matched");

        shareType.safeApprove(address(convertor), amount);
        uint256 convertAmount = convertor.convert(amount);

        uint256 exchangeRate = convertAmount.mul(1e18).div(amount);
        require(exchangeRate != 0, "exchange rate shouldn't be zero");

        convert.convertedExchangeRate = exchangeRate;
        convert.convertedShareType = IERC20(convertor.outputToken());
        _poolConvertors[poolId] = convertor;

        emit LSTPoolConverted(poolId, shareType, convert.convertedShareType, amount, convertAmount);
    }

    function _stakeTo(uint256 poolId, uint256 amount, address receiver) internal returns (bool) {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");
        uint256 addedShare;
        ConvertInfo memory convertInfo = convertInfos(poolId);
        if (address(convertInfo.convertedShareType) != address(0)) {
            ILSTConvert convertor = poolConvertors(poolId);
            require(address(convertor) != address(0), "pool convertor is not set");

            // if pool has converted, transfer the before share token to this firstly
            shareType.safeTransferFrom(msg.sender, address(this), amount);

            // convert share
            shareType.safeApprove(address(convertor), amount);
            uint256 convertedAmount = convertor.convert(amount);

            // must convert the share amount according to the exchange rate of converted pool
            addedShare = convertedAmount.mul(1e18).div(convertInfo.convertedExchangeRate);
        } else {
            // if pool hasn't converted, stake it directly
            shareType.safeTransferFrom(msg.sender, address(this), amount);
            addedShare = amount;
        }

        require(addedShare > 0, "cannot stake 0");
        _totalShares[poolId] = _totalShares[poolId].add(addedShare);
        _shares[poolId][receiver] = _shares[poolId][receiver].add(addedShare);

        emit Stake(receiver, poolId, addedShare);

        return true;
    }

    /// @notice Stake `amount` share token to `poolId` pool. If pool has been converted, still stake before share token.
    /// @param poolId The index of staking pool.
    /// @param amount The amount of share token to stake.
    function stake(uint256 poolId, uint256 amount)
        public
        virtual
        override(IStaking, UpgradeableStakingLST)
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        updateRewards(poolId, msg.sender)
        nonReentrant
        returns (bool)
    {
        return _stakeTo(poolId, amount, msg.sender);
    }

    /// @inheritdoc IStakingTo
    function stakeTo(uint256 poolId, uint256 amount, address receiver)
        public
        virtual
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        updateRewards(poolId, receiver)
        nonReentrant
        returns (bool)
    {
        require(receiver != address(0), "invalid receiver");
        return _stakeTo(poolId, amount, receiver);
    }

    /// @notice Unstake `amount` share token from `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param amount The share token amount to unstake. If pool has been converted, it's converted share token amount, not the share amount.
    /// @return Returns (success).
    function unstake(uint256 poolId, uint256 amount)
        public
        virtual
        override(IStaking, UpgradeableStakingLST)
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Unstake)
        updateRewards(poolId, msg.sender)
        nonReentrant
        returns (bool)
    {
        require(amount > 0, "cannot unstake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");
        require(_shares[poolId][msg.sender] >= amount, "share not enough");

        _totalShares[poolId] = _totalShares[poolId].sub(amount);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].sub(amount);

        ConvertInfo memory convertInfo = convertInfos(poolId);
        if (address(convertInfo.convertedShareType) != address(0)) {
            uint256 convertedAmount = amount.mul(convertInfo.convertedExchangeRate).div(1e18);
            require(convertedAmount != 0, "shouldn't be zero");

            convertInfo.convertedShareType.safeTransfer(msg.sender, convertedAmount);
        } else {
            shareType.safeTransfer(msg.sender, amount);
        }

        emit Unstake(msg.sender, poolId, amount);

        return true;
    }
}
