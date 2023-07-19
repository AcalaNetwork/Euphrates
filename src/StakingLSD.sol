// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./IHoma.sol";
import "./ILiquidCrowdloan.sol";
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

    address public immutable DOT;
    address public immutable LCDOT;
    address public immutable LDOT;
    address public immutable TDOT;
    address public immutable HOMA;
    address public immutable STABLE_ASSET;
    address public immutable LIQUID_CROWDLOAN;

    mapping(uint256 => ConvertInfo) private _convertInfos;

    constructor(
        address dot,
        address lcdot,
        address ldot,
        address tdot,
        address homa,
        address stableAsset,
        address liquidCrowdloan
    ) {
        require(dot != address(0), "dot address is zero");
        require(lcdot != address(0), "lcDOT address is zero");
        require(ldot != address(0), "lDOT address is zero");
        require(tdot != address(0), "tDOT address is zero");
        require(homa != address(0), "homa address is zero");
        require(stableAsset != address(0), "stableAsset address is zero");
        require(liquidCrowdloan != address(0), "liquidCrowdloan address is zero");
        DOT = dot;
        LCDOT = lcdot;
        LDOT = ldot;
        TDOT = tdot;
        HOMA = homa;
        STABLE_ASSET = stableAsset;
        LIQUID_CROWDLOAN = liquidCrowdloan;
    }

    function convertInfos(uint256 poolId) public view returns (ConvertInfo memory) {
        return _convertInfos[poolId];
    }

    function convertLSDPool(uint256 poolId, ConvertType convertType) external onlyOwner whenNotPaused {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) == LCDOT, "share token must be LcDOT");

        ConvertInfo storage convert = _convertInfos[poolId];
        require(address(convert.convertedShareType) == address(0), "already converted");

        uint256 amount = totalShares(poolId);
        require(amount > 0, "pool is empty");

        // redeem LcDOT to DOT at 1:1
        ILiquidCrowdloan(LIQUID_CROWDLOAN).redeem(amount);

        if (convertType == ConvertType.Lcdot2Ldot) {
            uint256 beforeLdotAmount = IERC20(LDOT).balanceOf(address(this));
            IHoma(HOMA).mint(amount);
            uint256 afterLdotAmount = IERC20(LDOT).balanceOf(address(this));
            uint256 exchangeRate = afterLdotAmount.sub(beforeLdotAmount).mul(1e18).div(amount);

            require(exchangeRate != 0, "exchange rate shouldn't be zero");

            convert.convertedShareType = IERC20(LDOT);
            convert.convertedExchangeRate = exchangeRate;
        } else if (convertType == ConvertType.Lcdot2Tdot) {
            uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));

            // some params is deadcode, Stable Asset of tDOT on Acala:
            // tDOT pool id: 0
            // assets length: 2
            // asset index of DOT: 0
            // asset index of LDOT: 1
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
        require(amount > 0, "cannot stake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");

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

        emit Stake(msg.sender, poolId, amount);

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
        require(amount > 0, "cannot unstake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");

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
