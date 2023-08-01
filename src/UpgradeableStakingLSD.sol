// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";
import "@AcalaNetwork/predeploy-contracts/liquid-crowdloan/ILiquidCrowdloan.sol";
import "./UpgradeableStakingCommon.sol";

/// @title UpgradeableStakingLSD Contract
/// @author Acala Developers
/// @notice This staking contract can convert the share token to it's LSD. It just support LcDOT token on Acala.
/// @dev After pool's share is converted into its LSD token, this pool can be staked with LSD token and before token both.
/// This version conforms to the specification for upgradeable contracts.
contract UpgradeableStakingLSD is UpgradeableStakingCommon {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The pool's share token is converted into its LSD token.
    /// @param poolId The pool id.
    /// @param beforeShareType The share token before converted.
    /// @param afterShareType The share token after converted.
    /// @param beforeShareTokenAmount The share token amount before converted.
    /// @param afterShareTokenAmount The share token amount after converted.
    event LSDPoolConverted(
        uint256 poolId,
        IERC20 beforeShareType,
        IERC20 afterShareType,
        uint256 beforeShareTokenAmount,
        uint256 afterShareTokenAmount
    );

    struct ConvertInfo {
        // The converted LSD token.
        IERC20 convertedShareType;
        // This is a snapshot of the ratio between share amount to new share token amount at the moment of conversion. 1e18 is 1:1
        uint256 convertedExchangeRate;
    }

    enum ConvertType {
        LCDOT2LDOT,
        LCDOT2TDOT,
        DOT2LDOT,
        DOT2TDOT
    }

    /// @notice The DOT token address.
    address public DOT;

    /// @notice The LcDOT token address.
    address public LCDOT;

    /// @notice The LDOT token address.
    address public LDOT;

    /// @notice The tDOT token address.
    address public TDOT;

    /// @notice The Homa predeploy contract address.
    address public HOMA;

    /// @notice The StableAsset predeploy contract address.
    address public STABLE_ASSET;

    /// @notice The LiquidCrowdloan predeploy contract address.
    address public LIQUID_CROWDLOAN;

    /// @dev The LSD convert info info of pool.
    /// (poolId => convertInfo)
    mapping(uint256 => ConvertInfo) private _convertInfos;

    /// @dev overwrite initialize() to mute initializer of UpgradeableStakingCommon
    function initialize() public override {}

    /// @notice The initialize function.
    /// @dev proxy contract will call this when firstly fetch this contract as the implementation contract.
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

    /// @notice Get the LSD convertion info of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns convert info.
    function convertInfos(uint256 poolId) public view returns (ConvertInfo memory) {
        return _convertInfos[poolId];
    }

    /// @dev redeem `amount` LcDOT token on LiquidCrowdloan contract.
    /// @param amount The amount of LcDOT to redeem.
    /// @return redeemCurrency The token address of redeemed currency.
    /// @return redeemedAmount The amount of redeemed token.
    function _redeemLCDOT(uint256 amount) internal returns (address redeemCurrency, uint256 redeemedAmount) {
        require(amount > 0, "amount shouldn't be zero");
        redeemCurrency = ILiquidCrowdloan(LIQUID_CROWDLOAN).getRedeemCurrency();
        redeemedAmount = ILiquidCrowdloan(LIQUID_CROWDLOAN).redeem(amount);
    }

    /// @dev convert `amount` DOT token of this contract to LDOT token.
    /// @param amount The amount of DOT to convert.
    /// @return convertAmount The amount of converted LDOT.
    function _convertDOT2LDOT(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount > 0, "amount shouldn't be zero");

        uint256 beforeLdotAmount = IERC20(LDOT).balanceOf(address(this));
        bool success = IHoma(HOMA).mint(amount);
        require(success, "homa mint failed");

        uint256 afterLdotAmount = IERC20(LDOT).balanceOf(address(this));
        convertAmount = afterLdotAmount.sub(beforeLdotAmount);
    }

    /// @dev convert `amount` DOT token of this contract to TDOT token.
    /// @param amount The amount of DOT to convert.
    /// @return convertAmount The amount of converted TDOT.
    function _convertDOT2TDOT(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount > 0, "amount shouldn't be zero");

        // params for tDOT pool fo StableAsset on Acala:
        // tDOT pool id: 0
        // assets length: 2
        // asset index of DOT: 0
        // here deadcode these params
        (bool valid, address[] memory assets) = IStableAsset(STABLE_ASSET).getStableAssetPoolTokens(0);
        require(valid && assets[0] == DOT, "invalid stable asset pool");

        uint256[] memory paramAmounts = new uint256[](2);
        paramAmounts[0] = amount;
        paramAmounts[1] = 0;

        uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));
        bool success = IStableAsset(STABLE_ASSET).stableAssetMint(0, paramAmounts, 0);
        require(success, "stable-asset mint failed");

        uint256 afterTdotAmount = IERC20(TDOT).balanceOf(address(this));
        convertAmount = afterTdotAmount.sub(beforeTdotAmount);
    }

    /// @dev convert `amount` LDOT token of this contract to TDOT token.
    /// @param amount The amount of LDOT to convert.
    /// @return convertAmount The amount of converted TDOT.
    function _convertLDOT2TDOT(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount > 0, "amount shouldn't be zero");

        // params for tDOT pool fo StableAsset on Acala:
        // tDOT pool id: 0
        // assets length: 2
        // asset index of LDOT: 1
        // here deadcode these params
        (bool valid, address[] memory assets) = IStableAsset(STABLE_ASSET).getStableAssetPoolTokens(0);
        require(valid && assets[1] == LDOT, "invalid stable asset pool");

        uint256[] memory paramAmounts = new uint256[](2);
        paramAmounts[0] = 0;
        paramAmounts[1] = amount;

        uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));
        bool success = IStableAsset(STABLE_ASSET).stableAssetMint(0, paramAmounts, 0);
        require(success, "stable-asset mint failed");

        uint256 afterTdotAmount = IERC20(TDOT).balanceOf(address(this));
        convertAmount = afterTdotAmount.sub(beforeTdotAmount);
    }

    /// @dev convert `amount` LcDOT token of this contract to LDOT token.
    /// @param amount The amount of LcDOT to convert.
    /// @return convertAmount The amount of converted LDOT.
    function _convertLCDOT2LDOT(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount > 0, "amount shouldn't be zero");

        // redeem LcDOT by LiquidCrowdloan.
        (address redeemCurrency, uint256 redeemedAmount) = _redeemLCDOT(amount);

        if (redeemCurrency == LDOT) {
            convertAmount = redeemedAmount;
        } else if (redeemCurrency == DOT) {
            convertAmount = _convertDOT2LDOT(redeemedAmount);
        } else {
            revert("unsupported convert");
        }
    }

    /// @dev convert `amount` LcDOT token of this contract to TDOT token.
    /// @param amount The amount of LcDOT to convert.
    /// @return convertAmount The amount of converted TDOT.
    function _convertLCDOT2TDOT(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount != 0, "amount shouldn't be zero");

        // redeem LcDOT by LiquidCrowdloan.
        (address redeemCurrency, uint256 redeemedAmount) = _redeemLCDOT(amount);

        if (redeemCurrency == TDOT) {
            convertAmount = redeemedAmount;
        } else if (redeemCurrency == DOT) {
            convertAmount = _convertDOT2TDOT(redeemedAmount);
        } else if (redeemCurrency == LDOT) {
            convertAmount = _convertLDOT2TDOT(redeemedAmount);
        } else {
            revert("unsupported convert");
        }
    }

    /// @notice convert the share token of ‘poolId’ pool to LSD token by `convertType`.
    /// @param poolId The index of staking pool.
    /// @param convertType The convert type.
    function convertLSDPool(uint256 poolId, ConvertType convertType) external onlyOwner whenNotPaused {
        IERC20 shareType = shareTypes(poolId);
        ConvertInfo storage convert = _convertInfos[poolId];
        require(address(convert.convertedShareType) == address(0), "already converted");

        uint256 amount = totalShares(poolId);
        require(amount > 0, "pool is empty");

        uint256 convertAmount;

        if (convertType == ConvertType.LCDOT2LDOT) {
            require(address(shareType) == LCDOT, "share token must be LcDOT");

            convertAmount = _convertLCDOT2LDOT(amount);
            convert.convertedShareType = IERC20(LDOT);
        } else if (convertType == ConvertType.LCDOT2TDOT) {
            require(address(shareType) == LCDOT, "share token must be LcDOT");

            convertAmount = _convertLCDOT2TDOT(amount);
            convert.convertedShareType = IERC20(TDOT);
        } else if (convertType == ConvertType.DOT2LDOT) {
            require(address(shareType) == DOT, "share token must be DOT");

            convertAmount = _convertDOT2LDOT(amount);
            convert.convertedShareType = IERC20(LDOT);
        } else if (convertType == ConvertType.DOT2TDOT) {
            require(address(shareType) == DOT, "share token must be DOT");

            convertAmount = _convertDOT2TDOT(amount);
            convert.convertedShareType = IERC20(TDOT);
        } else {
            revert("unsupported convert");
        }

        uint256 exchangeRate = convertAmount.mul(1e18).div(amount);
        require(exchangeRate != 0, "exchange rate shouldn't be zero");
        convert.convertedExchangeRate = exchangeRate;
        emit LSDPoolConverted(poolId, shareType, convert.convertedShareType, amount, convertAmount);
    }

    /// @notice Stake `amount` share token to `poolId` pool. If pool has been converted, still stake before share token.
    /// @param poolId The index of staking pool.
    /// @param amount The amount of share token to stake.
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
            // if pool has converted, transfer the before share token to this firstly
            shareType.safeTransferFrom(msg.sender, address(this), amount);

            uint256 convertedAmount;
            if (address(shareType) == LCDOT && address(convertInfo.convertedShareType) == LDOT) {
                convertedAmount = _convertLCDOT2LDOT(amount);
            } else if (address(shareType) == LCDOT && address(convertInfo.convertedShareType) == TDOT) {
                convertedAmount = _convertLCDOT2TDOT(amount);
            } else if (address(shareType) == DOT && address(convertInfo.convertedShareType) == LDOT) {
                convertedAmount = _convertDOT2LDOT(amount);
            } else if (address(shareType) == DOT && address(convertInfo.convertedShareType) == LDOT) {
                convertedAmount = _convertDOT2TDOT(amount);
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

    /// @notice Unstake `amount` share token from `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param amount The share token amount to unstake. If pool has been converted, it's converted share token amount, not the share amount.
    /// @return Returns (success).
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
