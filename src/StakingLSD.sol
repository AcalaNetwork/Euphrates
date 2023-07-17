// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./IHoma.sol";
import "./IMockLiquidCrowdloan.sol";
import "./IStableAsset.sol";
import "./StakingCommon.sol";

contract StakingLSD is StakingCommon {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event LSDPoolConverted(uint256 poolId, IERC20 beforeShareType, IERC20 afterShareType, uint256 exchangeRate);

    struct ConvertInfo {
        IERC20 convertedShareType;
        uint256 convertedExchangeRate; // 旧的shareToken 同转化后的 shareToken 的兑换比例， 1e18 是 100%
    }

    enum ConvertType {
        Lcdot2Ldot,
        Lcdot2Tdot
    }

    address public constant DOT = 0x0000000000000000000100000000000000000002;
    address public constant LCDOT = 0x000000000000000000040000000000000000000d;
    address public constant LDOT = 0x0000000000000000000100000000000000000003;
    address public constant TDOT = 0x0000000000000000000300000000000000000000;
    address public constant HOMA = 0x0000000000000000000000000000000000000805;
    address public constant STABLE_ASSET = 0x0000000000000000000000000000000000000804;
    address public constant LIQUID_CROWDLOAN = 0x0000000000000000000100000000000000000018; // TODO: did not existed, need config

    mapping(uint256 => ConvertInfo) private _convertInfos;

    function convertInfos(uint256 poolId) public view returns (ConvertInfo memory) {
        return _convertInfos[poolId];
    }

    function convertLSDPool(uint256 poolId, ConvertType convertType) external onlyOwner whenNotPaused {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) == LCDOT, "Share token must be Lcdot");

        ConvertInfo storage convert = _convertInfos[poolId];
        require(address(convert.convertedShareType) == address(0), "Already converted");

        // TODO: approve LcDOT to LIQUID_CROWDLOAN and call redeem to convert LcDOT to DOT;
        uint256 amount = totalShares(poolId);

        if (convertType == ConvertType.Lcdot2Ldot) {
            uint256 exchangeRate = IHoma(HOMA).getExchangeRate();
            require(exchangeRate != 0, "exchange rate shouldn't be zero");

            uint256 beforeLdotAmount = IERC20(LDOT).balanceOf(address(this));
            IHoma(HOMA).mint(amount);
            uint256 afterLdotAmount = IERC20(LDOT).balanceOf(address(this));

            require(
                amount.mul(exchangeRate).div(1e18).add(beforeLdotAmount) <= afterLdotAmount, "invalid exchange rate"
            );

            convert.convertedShareType = IERC20(LDOT);
            convert.convertedExchangeRate = exchangeRate;
        } else if (convertType == ConvertType.Lcdot2Tdot) {
            uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = amount;
            amounts[1] = 0;
            IStableAsset(STABLE_ASSET).stableAssetMint(0, amounts, 0);
            uint256 afterTdotAmount = IERC20(TDOT).balanceOf(address(this));
            uint256 exchangeRate = afterTdotAmount.sub(beforeTdotAmount).mul(1e18).div(amount);

            require(exchangeRate != 0, "exchange rate shouldn't be zero");

            convert.convertedShareType = IERC20(TDOT);
            convert.convertedExchangeRate = exchangeRate;
        }

        emit LSDPoolConverted(poolId, shareType, convert.convertedShareType, convert.convertedExchangeRate);
    }

    // NOTE: override the impl of super contract, explicitly all modifiers
    function stake(uint256 poolId, uint256 amount)
        public
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "Cannot stake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "Invalid pool");

        ConvertInfo memory convertInfo = convertInfos(poolId);
        if (address(convertInfo.convertedShareType) != address(0)) {
            uint256 convertedAmount = amount.mul(convertInfo.convertedExchangeRate).div(1e18);
            require(convertedAmount != 0, "shouldn't be zero");

            convertInfo.convertedShareType.safeTransferFrom(msg.sender, address(this), convertedAmount);
        } else {
            shareType.safeTransferFrom(msg.sender, address(this), amount);
        }

        _totalShares[poolId] = _totalShares[poolId].add(amount);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].add(amount);

        emit Staked(poolId, msg.sender, amount);

        return true;
    }

    // NOTE: override the impl of super contract, explicitly all modifiers
    function unstake(uint256 poolId, uint256 amount)
        public
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Unstake)
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "Cannot unstake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "Invalid pool");

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

        emit Unstaked(poolId, msg.sender, amount);

        return true;
    }
}
