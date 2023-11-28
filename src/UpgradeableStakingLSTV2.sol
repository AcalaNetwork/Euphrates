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
import "./ILSTConvert.sol";

/// @title IStakingTo Interface
/// @author Acala Developers
/// @notice You can use this integrate Acala LST staking into your contract.
interface IStakingTo is IStaking {
    /// @notice Stake share to other.
    /// @param poolId The index of staking pool.
    /// @param amount The share amount to stake.
    /// @param receiver The share receiver.
    /// @return Returns (success).
    function stakeTo(
        uint256 poolId,
        uint256 amount,
        address receiver
    ) external returns (bool);
}

/// @title UpgradeableStakingLSTV2 Contract
/// @author Acala Developers
/// @notice This staking contract can convert the share token to it's LST. It just support LcDOT token on Acala.
/// @dev After pool's share is converted into its LST token, this pool can be staked with LST token and before token both.
/// This version conforms to the specification for upgradeable contracts.
contract UpgradeableStakingLSTV2 is UpgradeableStakingCommon, IStakingTo {
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

    /// @dev The LST convert info info of pool.
    /// (poolId => convertInfo)
    mapping(uint256 => ConvertInfo) private _convertInfos;

    /// @dev The LST convertor of pool.
    /// (poolId => ILSTConvert)
    mapping(uint256 => ILSTConvert) private _poolConvertors;

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
        require(
            liquidCrowdloan != address(0),
            "LIQUID_CROWDLOAN address is zero"
        );
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
    function convertInfos(
        uint256 poolId
    ) public view returns (ConvertInfo memory) {
        return _convertInfos[poolId];
    }

    /// @notice Get the LST convertor of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @return Returns convertor address.
    function poolConvertors(uint256 poolId) public view returns (ILSTConvert) {
        return _poolConvertors[poolId];
    }

    /// @notice Reset the `convertor` as the convertor of `poolId` pool.
    /// @param poolId The index of staking pool.
    /// @param convertor The LST convertor.
    function resetPoolConvertor(
        uint256 poolId,
        ILSTConvert convertor
    ) public onlyOwner whenNotPaused {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");
        IERC20 convertedShareTypes = convertInfos(poolId).convertedShareType;
        require(
            address(convertedShareTypes) != address(0),
            "pool must be already converted"
        );

        require(
            convertor.inputToken() == address(shareType) &&
                convertor.outputToken() == address(convertedShareTypes),
            "convertor is not matched"
        );

        _poolConvertors[poolId] = convertor;
    }

    /// @dev convert `amount` WTDOT token of this contract to TDOT token.
    /// @param amount The amount of WTDOT to convert.
    /// @return convertAmount The amount of converted TDOT.
    function _convertWTDOT2TDOT(
        uint256 amount
    ) internal returns (uint256 convertAmount) {
        require(amount != 0, "amount shouldn't be zero");
        return IWTDOT(WTDOT).withdraw(amount);
    }

    /// @dev convert `amount` TDOT token of this contract to WTDOT token.
    /// @param amount The amount of TDOT to convert.
    /// @return convertAmount The amount of converted WTDOT.
    function _convertTDOT2WTDOT(
        uint256 amount
    ) internal returns (uint256 convertAmount) {
        require(amount != 0, "amount shouldn't be zero");
        IERC20(TDOT).safeApprove(WTDOT, amount);
        return IWTDOT(WTDOT).deposit(amount);
    }

    /// @notice convert the share token of ‘poolId’ pool to LST token by `convertor`.
    /// @param poolId The index of staking pool.
    /// @param convertor The convert contract address.
    function convertLSTPool(
        uint256 poolId,
        ILSTConvert convertor
    ) external onlyOwner whenNotPaused {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");
        ConvertInfo storage convert = _convertInfos[poolId];
        require(
            address(convert.convertedShareType) == address(0),
            "already converted"
        );

        uint256 amount = totalShares(poolId);
        require(amount > 0, "pool is empty");

        require(
            convertor.inputToken() == address(shareType),
            "convertor is not matched"
        );

        shareType.safeApprove(address(convertor), amount);
        uint256 convertAmount = convertor.convert(amount);

        uint256 exchangeRate = convertAmount.mul(1e18).div(amount);
        require(exchangeRate != 0, "exchange rate shouldn't be zero");

        convert.convertedExchangeRate = exchangeRate;
        convert.convertedShareType = IERC20(convertor.outputToken());
        _poolConvertors[poolId] = convertor;

        emit LSTPoolConverted(
            poolId,
            shareType,
            convert.convertedShareType,
            amount,
            convertAmount
        );
    }

    function _stakeTo(
        uint256 poolId,
        uint256 amount,
        address receiver
    ) internal returns (bool) {
        IERC20 shareType = shareTypes(poolId);
        require(address(shareType) != address(0), "invalid pool");
        uint256 addedShare;
        ConvertInfo memory convertInfo = convertInfos(poolId);
        if (address(convertInfo.convertedShareType) != address(0)) {
            ILSTConvert convertor = poolConvertors(poolId);
            require(
                address(poolConvertors(poolId)) != address(0),
                "pool convertor is not set"
            );

            // if pool has converted, transfer the before share token to this firstly
            shareType.safeTransferFrom(msg.sender, address(this), amount);

            // convert share
            shareType.safeApprove(address(convertor), amount);
            uint256 convertedAmount = convertor.convert(amount);

            // must convert the share amount according to the exchange rate of converted pool
            addedShare = convertedAmount.mul(1e18).div(
                convertInfo.convertedExchangeRate
            );
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
        _shares[poolId][receiver] = _shares[poolId][receiver].add(addedShare);

        emit Stake(receiver, poolId, addedShare);

        return true;
    }

    /// @notice Stake `amount` share token to `poolId` pool. If pool has been converted, still stake before share token.
    /// @param poolId The index of staking pool.
    /// @param amount The amount of share token to stake.
    function stake(
        uint256 poolId,
        uint256 amount
    )
        public
        override(IStaking, UpgradeableStakingCommon)
        whenNotPaused
        poolOperationNotPaused(poolId, Operation.Stake)
        updateRewards(poolId, msg.sender)
        nonReentrant
        returns (bool)
    {
        return _stakeTo(poolId, amount, msg.sender);
    }

    /// @inheritdoc IStakingTo
    function stakeTo(
        uint256 poolId,
        uint256 amount,
        address receiver
    )
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
    function unstake(
        uint256 poolId,
        uint256 amount
    )
        public
        override(IStaking, UpgradeableStakingCommon)
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
            uint256 convertedAmount = amount
                .mul(convertInfo.convertedExchangeRate)
                .div(1e18);
            require(convertedAmount != 0, "shouldn't be zero");

            if (address(convertInfo.convertedShareType) == WTDOT) {
                uint256 tdotAmount = _convertWTDOT2TDOT(convertedAmount);
                IERC20(TDOT).safeTransfer(msg.sender, tdotAmount);
            } else {
                convertInfo.convertedShareType.safeTransfer(
                    msg.sender,
                    convertedAmount
                );
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
