// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";
import "@AcalaNetwork/predeploy-contracts/liquid-crowdloan/ILiquidCrowdloan.sol";
import "./UpgradeableStakingCommon.sol";
import "./WrappedTDOT.sol";

/// @title UpgradeableStakingLST Contract
/// @author Acala Developers
/// @notice This staking contract can convert the share token to it's LST. It just support LcDOT token on Acala.
/// @dev After pool's share is converted into its LST token, this pool can be staked with LST token and before token both.
/// This version conforms to the specification for upgradeable contracts.
contract UpgradeableStakingLST is UpgradeableStakingCommon {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The pool's share token is converted into its LST token.
    /// @param poolId The pool id.
    /// @param beforeShareType The share token before converted.
    /// @param afterShareType The share token after converted.
    /// @param beforeShareTokenAmount The share token amount before converted.
    /// @param afterShareTokenAmount The share token amount after converted.
    event LSTPoolConverted(
        uint256 poolId,
        IERC20 beforeShareType,
        IERC20 afterShareType,
        uint256 beforeShareTokenAmount,
        uint256 afterShareTokenAmount
    );

    struct ConvertInfo {
        // The converted LST token.
        IERC20 convertedShareType;
        // This is a snapshot of the ratio between share amount to new share token amount at the moment of conversion. 1e18 is 1:1
        uint256 convertedExchangeRate;
    }

    enum ConvertType {
        LCDOT2LDOT,
        LCDOT2WTDOT,
        DOT2LDOT,
        DOT2WTDOT
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

    /// @notice The Wrapped TDOT (WTDOT) token address.
    address public WTDOT;

    /// @notice The threshold amount of DOT to mint by HOMA.
    uint256 public constant HOMA_MINT_THRESHOLD = 50_000_000_000; // 5 DOT

    /// @notice The LST convert info info of pool.
    /// (poolId => convertInfo)
    mapping(uint256 => ConvertInfo) internal _convertInfos;

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
        address liquidCrowdloan,
        address wtdot
    ) public initializer {
        require(dot != address(0), "DOT address is zero");
        require(lcdot != address(0), "lCDOT address is zero");
        require(ldot != address(0), "LDOT address is zero");
        require(tdot != address(0), "TDOT address is zero");
        require(homa != address(0), "HOMA address is zero");
        require(stableAsset != address(0), "STABLE_ASSET address is zero");
        require(liquidCrowdloan != address(0), "LIQUID_CROWDLOAN address is zero");
        require(wtdot != address(0), "WTDOT address is zero");
        DOT = dot;
        LCDOT = lcdot;
        LDOT = ldot;
        TDOT = tdot;
        HOMA = homa;
        STABLE_ASSET = stableAsset;
        LIQUID_CROWDLOAN = liquidCrowdloan;
        WTDOT = wtdot;

        __Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /// @notice Get the LST convertion info of `poolId` pool.
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
        // asset index of LDOT: 1
        // here deadcode these params
        (bool valid, address[] memory assets) = IStableAsset(STABLE_ASSET).getStableAssetPoolTokens(0);
        require(valid && assets[0] == DOT && assets[1] == LDOT, "invalid stable asset pool");
        uint256[] memory paramAmounts = new uint256[](2);

        if (amount.div(2) >= HOMA_MINT_THRESHOLD) {
            uint256 ldotAmount = _convertDOT2LDOT(amount.div(2));

            // convert LDOT amount to rebased LDOT amount as the param
            // NOTE: the precision of Homa.getExchangeRate is 1e18
            uint256 ldotParamAmount = ldotAmount.mul(IHoma(HOMA).getExchangeRate()).div(1e18);
            paramAmounts[0] = amount.sub(amount.div(2));
            paramAmounts[1] = ldotParamAmount;
        } else {
            paramAmounts[0] = amount;
            paramAmounts[1] = 0;
        }

        uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));
        // NOTE: allow max slippage here
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

        // convert LDOT amount to rebased LDOT amount as the param
        // NOTE: the precision of Homa.getExchangeRate is 1e18
        uint256 ldotParamAmount = amount.mul(IHoma(HOMA).getExchangeRate()).div(1e18);

        uint256[] memory paramAmounts = new uint256[](2);
        paramAmounts[0] = 0;
        paramAmounts[1] = ldotParamAmount;

        uint256 beforeTdotAmount = IERC20(TDOT).balanceOf(address(this));
        // NOTE: allow max slippage here
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

    /// @dev convert `amount` WTDOT token of this contract to TDOT token.
    /// @param amount The amount of WTDOT to convert.
    /// @return convertAmount The amount of converted TDOT.
    function _convertWTDOT2TDOT(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount != 0, "amount shouldn't be zero");
        return IWTDOT(WTDOT).withdraw(amount);
    }

    /// @dev convert `amount` TDOT token of this contract to WTDOT token.
    /// @param amount The amount of TDOT to convert.
    /// @return convertAmount The amount of converted WTDOT.
    function _convertTDOT2WTDOT(uint256 amount) internal returns (uint256 convertAmount) {
        require(amount != 0, "amount shouldn't be zero");
        IERC20(TDOT).safeApprove(WTDOT, amount);
        return IWTDOT(WTDOT).deposit(amount);
    }

    /// @notice convert the share token of ‘poolId’ pool to LST token by `convertType`.
    /// @param poolId The index of staking pool.
    /// @param convertType The convert type.
    function convertLSTPool(uint256 poolId, ConvertType convertType) external virtual onlyOwner whenNotPaused {
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
        } else if (convertType == ConvertType.DOT2LDOT) {
            require(address(shareType) == DOT, "share token must be DOT");

            convertAmount = _convertDOT2LDOT(amount);
            convert.convertedShareType = IERC20(LDOT);
        } else if (convertType == ConvertType.LCDOT2WTDOT) {
            require(address(shareType) == LCDOT, "share token must be LcDOT");

            uint256 tdotAmount = _convertLCDOT2TDOT(amount);
            convertAmount = _convertTDOT2WTDOT(tdotAmount);
            convert.convertedShareType = IERC20(WTDOT);
        } else if (convertType == ConvertType.DOT2WTDOT) {
            require(address(shareType) == DOT, "share token must be DOT");

            uint256 tdotAmount = _convertDOT2TDOT(amount);
            convertAmount = _convertTDOT2WTDOT(tdotAmount);
            convert.convertedShareType = IERC20(WTDOT);
        } else {
            revert("unsupported convert");
        }

        uint256 exchangeRate = convertAmount.mul(1e18).div(amount);
        require(exchangeRate != 0, "exchange rate shouldn't be zero");
        convert.convertedExchangeRate = exchangeRate;
        emit LSTPoolConverted(poolId, shareType, convert.convertedShareType, amount, convertAmount);
    }

    /// @notice Stake `amount` share token to `poolId` pool. If pool has been converted, still stake before share token.
    /// @param poolId The index of staking pool.
    /// @param amount The amount of share token to stake.
    function stake(uint256 poolId, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        updateRewards(poolId, msg.sender)
        nonReentrant
        returns (bool)
    {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");

        uint256 addedShare;
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
            } else if (address(shareType) == DOT && address(convertInfo.convertedShareType) == TDOT) {
                convertedAmount = _convertDOT2TDOT(amount);
            } else if (address(shareType) == LCDOT && address(convertInfo.convertedShareType) == WTDOT) {
                uint256 tdotAmount = _convertLCDOT2TDOT(amount);
                convertedAmount = _convertTDOT2WTDOT(tdotAmount);
            } else if (address(shareType) == DOT && address(convertInfo.convertedShareType) == WTDOT) {
                uint256 tdotAmount = _convertDOT2TDOT(amount);
                convertedAmount = _convertTDOT2WTDOT(tdotAmount);
            } else {
                revert("unsupported converted share token");
            }

            // must convert the share amount according to the exchange rate of converted pool
            addedShare = convertedAmount.mul(1e18).div(convertInfo.convertedExchangeRate);
        } else if (address(shareType) == WTDOT) {
            // transfer TDOT to this, convert it to WTDOT and stake it
            IERC20(TDOT).safeTransferFrom(msg.sender, address(this), amount);
            addedShare = _convertTDOT2WTDOT(amount);
        } else {
            // if pool hasn't converted, stake it directly
            shareType.safeTransferFrom(msg.sender, address(this), amount);
            addedShare = amount;
        }

        require(addedShare > 0, "cannot stake 0");
        _totalShares[poolId] = _totalShares[poolId].add(addedShare);
        _shares[poolId][msg.sender] = _shares[poolId][msg.sender].add(addedShare);

        emit Stake(msg.sender, poolId, addedShare);

        return true;
    }

    /// @notice Unstake `amount` share token from `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param amount The share token amount to unstake. If pool has been converted, it's converted share token amount, not the share amount.
    /// @return Returns (success).
    function unstake(uint256 poolId, uint256 amount)
        public
        virtual
        override
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

            if (address(convertInfo.convertedShareType) == WTDOT) {
                uint256 tdotAmount = _convertWTDOT2TDOT(convertedAmount);
                IERC20(TDOT).safeTransfer(msg.sender, tdotAmount);
            } else {
                convertInfo.convertedShareType.safeTransfer(msg.sender, convertedAmount);
            }
        } else if (address(shareType) == WTDOT) {
            uint256 tdotAmount = _convertWTDOT2TDOT(amount);
            IERC20(TDOT).safeTransfer(msg.sender, tdotAmount);
        } else {
            shareType.safeTransfer(msg.sender, amount);
        }

        emit Unstake(msg.sender, poolId, amount);

        return true;
    }
}
