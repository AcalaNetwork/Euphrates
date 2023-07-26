// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";
import "@AcalaNetwork/predeploy-contracts/liquid-crowdloan/ILiquidCrowdloan.sol";
import "./UpgradeableStakingCommon.sol";

contract UpgradeableStakingLSD is UpgradeableStakingCommon {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event LSDPoolConverted(
        uint256 poolId,
        IERC20 beforeShareType,
        IERC20 afterShareType,
        uint256 beforeShareAmount,
        uint256 afterShareAmount
    );

    struct ConvertInfo {
        IERC20 convertedShareType;
        uint256 convertedExchangeRate; // 旧的shareToken 同转化后的 shareToken 的兑换比例， 1e18 是 100%
    }

    enum ConvertType {
        Lcdot2Ldot,
        Lcdot2Tdot
    }

    address public DOT;
    address public LCDOT;
    address public LDOT;
    address public TDOT;
    address public HOMA;
    address public STABLE_ASSET;
    address public LIQUID_CROWDLOAN;

    mapping(uint256 => ConvertInfo) private _convertInfos;

    // overwrite initialize() to mute initializer for UpgradeableStakingCommon
    function initialize() public override {}

    function initialize(
        address dot,
        address lcdot,
        address ldot,
        address tdot,
        address homa,
        address stableAsset,
        address liquidCrowdloan
    ) public initializer {
        require(dot != address(0), "DOT address is zero");
        require(lcdot != address(0), "lCDOT address is zero");
        require(ldot != address(0), "LDOT address is zero");
        require(tdot != address(0), "TDOT address is zero");
        require(homa != address(0), "HOMA address is zero");
        require(stableAsset != address(0), "STABLE_ASSET address is zero");
        require(liquidCrowdloan != address(0), "LIQUID_CROWDLOAN address is zero");
        DOT = dot;
        LCDOT = lcdot;
        LDOT = ldot;
        TDOT = tdot;
        HOMA = homa;
        STABLE_ASSET = stableAsset;
        LIQUID_CROWDLOAN = liquidCrowdloan;

        __Pausable_init();
        __Ownable_init();
    }

    function convertInfos(uint256 poolId) public view returns (ConvertInfo memory) {
        return _convertInfos[poolId];
    }

    function _convertLcdot2Ldot(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount > 0, "amount shouldn't be zero");
        address redeemCurrency = ILiquidCrowdloan(LIQUID_CROWDLOAN).getRedeemCurrency();

        if (redeemCurrency == LDOT) {
            // if redeemCurrency is LDOT, redeem LcDOT to LDOT directly by LiquidCrowdloan.
            convertAmount = ILiquidCrowdloan(LIQUID_CROWDLOAN).redeem(amount);
        } else if (redeemCurrency == DOT) {
            // if redeemCurrency is DOT, redeem LcDOT to DOT by LiquidCrowdloan firstly, then convert DOT to LDOT by Homa.
            uint256 redeemedAmount = ILiquidCrowdloan(LIQUID_CROWDLOAN).redeem(amount);

            uint256 beforeLdotAmount = IERC20(LDOT).balanceOf(address(this));
            bool success = IHoma(HOMA).mint(redeemedAmount);
            require(success, "homa mint failed");

            uint256 afterLdotAmount = IERC20(LDOT).balanceOf(address(this));
            convertAmount = afterLdotAmount.sub(beforeLdotAmount);
        } else {
            revert("unsupported convert");
        }
    }

    function _convertLcdot2Tdot(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount != 0, "amount shouldn't be zero");
        address redeemCurrency = ILiquidCrowdloan(LIQUID_CROWDLOAN).getRedeemCurrency();

        if (redeemCurrency == TDOT) {
            // if redeemCurrency is TDOT, redeem LcDOT to TDOT directly by LiquidCrowdloan.
            convertAmount = ILiquidCrowdloan(LIQUID_CROWDLOAN).redeem(amount);
        } else if (redeemCurrency == DOT) {
            // if redeemCurrency is DOT, redeem LcDOT to DOT by LiquidCrowdloan firstly, then convert DOT to TDOT by StableAsset.
            uint256 redeemedAmount = ILiquidCrowdloan(LIQUID_CROWDLOAN).redeem(amount);

            // params for tDOT pool fo StableAsset on Acala:
            // tDOT pool id: 0
            // assets length: 2
            // asset index of DOT: 0
            // here deadcode these params
            (bool valid, address[] memory assets) = IStableAsset(STABLE_ASSET).getStableAssetPoolTokens(0);
            require(valid && assets[0] == DOT, "invalid stable asset pool");

            uint256[] memory paramAmounts = new uint256[](2);
            paramAmounts[0] = redeemedAmount;
            paramAmounts[1] = 0;

            uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));
            bool success = IStableAsset(STABLE_ASSET).stableAssetMint(0, paramAmounts, 0);
            require(success, "stable-asset mint failed");

            uint256 afterTdotAmount = IERC20(TDOT).balanceOf(address(this));
            convertAmount = afterTdotAmount.sub(beforeTdotAmount);
        } else if (redeemCurrency == LDOT) {
            // if redeemCurrency is DOT, need redeem LcDOT to DOT by LiquidCrowdloan firstly, then convert DOT to TDOT by StableAsset.
            uint256 redeemedAmount = ILiquidCrowdloan(LIQUID_CROWDLOAN).redeem(amount);

            // params for tDOT pool fo StableAsset on Acala:
            // tDOT pool id: 0
            // assets length: 2
            // asset index of LDOT: 1
            // here deadcode these params
            (bool valid, address[] memory assets) = IStableAsset(STABLE_ASSET).getStableAssetPoolTokens(0);
            require(valid && assets[1] == LDOT, "invalid stable asset pool");

            uint256[] memory paramAmounts = new uint256[](2);
            paramAmounts[0] = 0;
            paramAmounts[1] = redeemedAmount;

            uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));
            bool success = IStableAsset(STABLE_ASSET).stableAssetMint(0, paramAmounts, 0);
            require(success, "stable-asset mint failed");

            uint256 afterTdotAmount = IERC20(TDOT).balanceOf(address(this));
            convertAmount = afterTdotAmount.sub(beforeTdotAmount);
        } else {
            revert("unsupported convert");
        }
    }

    function convertLSDPool(uint256 poolId, ConvertType convertType) external onlyOwner whenNotPaused {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) == LCDOT, "share token must be LcDOT");

        ConvertInfo storage convert = _convertInfos[poolId];
        require(address(convert.convertedShareType) == address(0), "already converted");

        uint256 amount = totalShares(poolId);
        require(amount > 0, "pool is empty");

        if (convertType == ConvertType.Lcdot2Ldot) {
            uint256 convertAmount = _convertLcdot2Ldot(amount);
            uint256 exchangeRate = convertAmount.mul(1e18).div(amount);
            require(exchangeRate != 0, "exchange rate shouldn't be zero");

            convert.convertedShareType = IERC20(LDOT);
            convert.convertedExchangeRate = exchangeRate;
            emit LSDPoolConverted(poolId, shareType, convert.convertedShareType, amount, convertAmount);
        } else if (convertType == ConvertType.Lcdot2Tdot) {
            uint256 convertAmount = _convertLcdot2Tdot(amount);
            uint256 exchangeRate = convertAmount.mul(1e18).div(amount);
            require(exchangeRate != 0, "exchange rate shouldn't be zero");

            convert.convertedShareType = IERC20(TDOT);
            convert.convertedExchangeRate = exchangeRate;
            emit LSDPoolConverted(poolId, shareType, convert.convertedShareType, amount, convertAmount);
        }
    }

    // stake before share token for converted pool
    function stakeBeforeShareToken(uint256 poolId, uint256 amount)
        public
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        updateRewards(poolId, msg.sender)
        returns (bool)
    {
        require(amount > 0, "cannot stake 0");
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");

        ConvertInfo memory convertInfo = convertInfos(poolId);
        if (address(shareType) == LCDOT && address(convertInfo.convertedShareType) != address(0)) {
            // if pool has converted, transfer the before share token to this firstly
            shareType.safeTransferFrom(msg.sender, address(this), amount);

            uint256 convertedAmount = 0;
            if (address(convertInfo.convertedShareType) == LDOT) {
                // convert LcDOT to LDOT
                convertedAmount = _convertLcdot2Ldot(amount);
            } else if (address(convertInfo.convertedShareType) == TDOT) {
                // convert LcDOT to TDOT
                convertedAmount = _convertLcdot2Tdot(amount);
            } else {
                revert("unsupported converted share token");
            }

            // must convert the share amount according to the exchange rate of converted pool
            uint256 convertedBeforeShareAmount = convertedAmount.mul(1e18).div(convertInfo.convertedExchangeRate);
            require(convertedBeforeShareAmount != 0, "cannot stake 0");

            _totalShares[poolId] = _totalShares[poolId].add(convertedBeforeShareAmount);
            _shares[poolId][msg.sender] = _shares[poolId][msg.sender].add(convertedBeforeShareAmount);

            emit Stake(msg.sender, poolId, convertedBeforeShareAmount);
        } else {
            // if pool hasn't converted, stake it directly
            shareType.safeTransferFrom(msg.sender, address(this), amount);

            _totalShares[poolId] = _totalShares[poolId].add(amount);
            _shares[poolId][msg.sender] = _shares[poolId][msg.sender].add(amount);

            emit Stake(msg.sender, poolId, amount);
        }

        return true;
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
            // if pool has converted, stake converted share token
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
