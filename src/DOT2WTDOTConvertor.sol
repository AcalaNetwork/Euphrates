// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/security/ReentrancyGuard.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";

import "./WrappedTDOT.sol";
import "./ILSTConvert.sol";

/// @title DOT2WTDOTConvertor Contract
/// @author Acala Developers
/// @notice Convert DOT to WTDOT by Homa protocal, StableAsset of Acala and WTDOT contract.
contract DOT2WTDOTConvertor is ILSTConvert, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice The StableAsset predeployed contract of Acala.
    address public immutable stableAsset;

    /// @notice The Homa predeployed contract of Acala.
    address public immutable homa;

    /// @notice The token address of DOT.
    address public immutable dot;

    /// @notice The token address of LDOT.
    address public immutable ldot;

    /// @notice The token address of TDOT.
    address public immutable tdot;

    /// @notice The token address of WTDOT.
    address public immutable wtdot;

    /// @notice The threshold amount of DOT to mint by HOMA.
    uint256 public constant HOMA_MINT_THRESHOLD = 50_000_000_000; // 5 DOT

    /// @notice Deploys DOT2WTDOTConvertor.
    /// @param stableAssetAddr The predeployed StableAsset contract of Acala.
    /// @param homaAddr The predeployed Homa contract of Acala.
    /// @param dotAddr The token address of DOT.
    /// @param ldotAddr The token address of LDOT.
    /// @param tdotAddr The token address of TDOT.
    /// @param wtdotAddr The WTDOT contract.
    constructor(
        address stableAssetAddr,
        address homaAddr,
        address dotAddr,
        address ldotAddr,
        address tdotAddr,
        address wtdotAddr
    ) {
        stableAsset = stableAssetAddr;
        homa = homaAddr;
        dot = dotAddr;
        ldot = ldotAddr;
        tdot = tdotAddr;
        wtdot = wtdotAddr;
    }

    /// @inheritdoc ILSTConvert
    function inputToken() external view override returns (address) {
        return dot;
    }

    /// @inheritdoc ILSTConvert
    function outputToken() external view override returns (address) {
        return wtdot;
    }

    /// @inheritdoc ILSTConvert
    function convert(uint256 inputAmount) external override returns (uint256) {
        return _convert(inputAmount, msg.sender);
    }

    /// @inheritdoc ILSTConvert
    function convertTo(uint256 inputAmount, address receiver) external override returns (uint256) {
        require(receiver != address(0), "DOT2WTDOTConvertor: zero address not allowed");
        return _convert(inputAmount, receiver);
    }

    /// @notice Convert `inputAmount` token and send output token to `receiver`.
    /// @param inputAmount The input token amount to convert.
    /// @param receiver The receiver for the converted output token.
    /// @return outputAmount The output token amount.
    function _convert(uint256 inputAmount, address receiver) internal returns (uint256 outputAmount) {
        require(inputAmount != 0, "DOT2WTDOTConvertor: invalid input amount");
        IERC20(dot).safeTransferFrom(msg.sender, address(this), inputAmount);

        // params for tDOT pool fo StableAsset on Acala:
        // tDOT pool id: 0
        // assets length: 2
        // asset index of DOT: 0
        // asset index of LDOT: 1
        // here deadcode these params
        (bool valid, address[] memory assets) = IStableAsset(stableAsset).getStableAssetPoolTokens(0);
        require(valid && assets[0] == dot && assets[1] == ldot, "DOT2WTDOTConvertor: invalid stable asset pool");
        uint256[] memory paramAmounts = new uint256[](2);

        if (inputAmount.div(2) >= HOMA_MINT_THRESHOLD) {
            uint256 beforeLdotAmount = IERC20(ldot).balanceOf(address(this));
            bool suc = IHoma(homa).mint(inputAmount.div(2));
            require(suc, "DOT2WTDOTConvertor: homa mint failed");
            uint256 afterLdotAmount = IERC20(ldot).balanceOf(address(this));
            uint256 ldotAmount = afterLdotAmount.sub(beforeLdotAmount);

            // convert LDOT amount to rebased LDOT amount as the param
            // NOTE: the precision of Homa.getExchangeRate is 1e18
            uint256 ldotParamAmount = ldotAmount.mul(IHoma(homa).getExchangeRate()).div(1e18);
            paramAmounts[0] = inputAmount.sub(inputAmount.div(2));
            paramAmounts[1] = ldotParamAmount;
        } else {
            paramAmounts[0] = inputAmount;
            paramAmounts[1] = 0;
        }

        uint256 beforeTdotAmount = IERC20(tdot).balanceOf(address(this));
        // NOTE: allow max slippage here
        bool success = IStableAsset(stableAsset).stableAssetMint(0, paramAmounts, 0);
        require(success, "DOT2WTDOTConvertor: stable-asset mint failed");
        uint256 afterTdotAmount = IERC20(tdot).balanceOf(address(this));
        uint256 tdotAmount = afterTdotAmount.sub(beforeTdotAmount);

        IERC20(tdot).safeApprove(wtdot, tdotAmount);
        outputAmount = IWTDOT(wtdot).deposit(tdotAmount);

        require(outputAmount > 0, "DOT2WTDOTConvertor: zero output");
        IERC20(wtdot).safeTransfer(receiver, outputAmount);
    }
}
