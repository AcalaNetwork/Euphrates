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

contract DOT2WTDOTConverter is ILSTConvert, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable stableAsset;
    address public immutable homa;
    address public immutable dot;
    address public immutable ldot;
    address public immutable tdot;
    address public immutable wtdot;
    uint256 public constant HOMA_MINT_THRESHOLD = 50_000_000_000; // 5 DOT

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

    function inputToken() external view override returns (address) {
        return dot;
    }

    function outputToken() external view override returns (address) {
        return wtdot;
    }

    function convertThreshold() external pure override returns (uint256) {
        return 0;
    }

    function convert(uint256 inputAmount) external override returns (uint256) {
        return _convert(inputAmount, msg.sender);
    }

    function convertTo(uint256 inputAmount, address receiver) external override returns (uint256) {
        require(receiver != address(0), "DOT2WTDOTConverter: zero address not allowed");
        return _convert(inputAmount, receiver);
    }

    function _convert(uint256 inputAmount, address receiver) internal returns (uint256 outputAmount) {
        require(inputAmount != 0, "DOT2WTDOTConverter: invalid input amount");
        IERC20(dot).safeTransferFrom(msg.sender, address(this), inputAmount);

        // params for tDOT pool fo StableAsset on Acala:
        // tDOT pool id: 0
        // assets length: 2
        // asset index of DOT: 0
        // asset index of LDOT: 1
        // here deadcode these params
        (bool valid, address[] memory assets) = IStableAsset(stableAsset).getStableAssetPoolTokens(0);
        require(valid && assets[0] == dot, "DOT2WTDOTConverter: invalid stable asset pool");
        uint256[] memory paramAmounts = new uint256[](2);

        if (inputAmount.div(2) >= HOMA_MINT_THRESHOLD) {
            uint256 beforeLdotAmount = IERC20(ldot).balanceOf(address(this));
            bool suc = IHoma(homa).mint(inputAmount.div(2));
            require(suc, "DOT2WTDOTConverter: homa mint failed");
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
        bool success = IStableAsset(stableAsset).stableAssetMint(0, paramAmounts, 0);
        require(success, "DOT2WTDOTConverter: stable-asset mint failed");
        uint256 afterTdotAmount = IERC20(tdot).balanceOf(address(this));
        uint256 tdotAmount = afterTdotAmount.sub(beforeTdotAmount);

        IERC20(tdot).safeApprove(wtdot, tdotAmount);
        outputAmount = IWTDOT(wtdot).deposit(tdotAmount);

        require(outputAmount > 0, "DOT2WTDOTConverter: zero output");
        IERC20(wtdot).safeTransfer(receiver, outputAmount);
    }
}
