// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@AcalaNetwork/predeploy-contracts/stable-asset/IStableAsset.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "./MockToken.sol";

contract MockStableAsset is IStableAsset {
    using SafeMath for uint256;

    address public immutable DOT;
    address public immutable LDOT;
    address public immutable TDOT;
    address public immutable HOMA;

    constructor(address dot, address ldot, address tdot, address homa) {
        DOT = dot;
        LDOT = ldot;
        TDOT = tdot;
        HOMA = homa;
    }

    function getStableAssetPoolTokens(uint32 poolId) external view returns (bool, address[] memory) {
        if (poolId != 0) {
            revert("MockStableAsset: invalid pool");
        }

        address[] memory assets = new address[](2);
        assets[0] = DOT;
        assets[1] = LDOT;

        return (true, assets);
    }

    function getStableAssetPoolTotalSupply(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function getStableAssetPoolPrecision(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function getStableAssetPoolMintFee(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function getStableAssetPoolSwapFee(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function getStableAssetPoolRedeemFee(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function stableAssetSwap(uint32 poolId, uint32 i, uint32 j, uint256 dx, uint256 minDY, uint32 assetLength)
        external
        returns (bool)
    {
        revert("MockStableAsset: unimplement");
    }

    function stableAssetMint(uint32 poolId, uint256[] calldata amounts, uint256 minMintAmount)
        external
        returns (bool)
    {
        if (poolId != 0) {
            revert("MockStableAsset: invalid pool");
        }
        if (amounts.length != 2) {
            revert("MockStableAsset: invalid amounts length");
        }

        uint256 dotAmount = amounts[0];
        uint256 rebasedLdotAmount = amounts[1];

        if (dotAmount == 0 && rebasedLdotAmount == 0) {
            revert("MockStableAsset: invalid amounts");
        }

        uint256 ldotAmount = rebasedLdotAmount.mul(1e18).div(IHoma(HOMA).getExchangeRate());
        MockToken(DOT).forceTransfer(msg.sender, address(this), dotAmount);
        MockToken(LDOT).forceTransfer(msg.sender, address(this), ldotAmount);

        // set DOT mint tDOT at 1:1, and LDOT mint tDOT at 1:10
        uint256 tdotAmount = dotAmount.add(ldotAmount.div(10));
        MockToken(TDOT).mint(msg.sender, tdotAmount);

        return true;
    }

    function stableAssetRedeem(uint32 poolId, uint256 redeemAmount, uint256[] calldata amounts)
        external
        returns (bool)
    {
        revert("MockStableAsset: unimplement");
    }

    function stableAssetRedeemSingle(
        uint32 poolId,
        uint256 redeemAmount,
        uint32 i,
        uint256 minRedeemAmount,
        uint32 assetLength
    ) external returns (bool) {
        revert("MockStableAsset: unimplement");
    }

    function stableAssetRedeemMulti(uint32 poolId, uint256[] calldata amounts, uint256 maxRedeemAmount)
        external
        returns (bool)
    {
        revert("MockStableAsset: unimplement");
    }
}

contract MockStableAssetV2 is IStableAsset {
    using SafeMath for uint256;

    address public immutable DOT;
    address public immutable LDOT;
    address public immutable TDOT;
    address public immutable HOMA;
    address public immutable USDCET;
    address public immutable USDT;
    address public immutable TUSD;

    constructor(address dot, address ldot, address tdot, address homa, address usdcet, address usdt, address tusd) {
        DOT = dot;
        LDOT = ldot;
        TDOT = tdot;
        HOMA = homa;
        USDCET = usdcet;
        USDT = usdt;
        TUSD = tusd;
    }

    function getStableAssetPoolTokens(uint32 poolId) external view returns (bool, address[] memory) {
        if (poolId == 0) {
            address[] memory assets = new address[](2);
            assets[0] = DOT;
            assets[1] = LDOT;
            return (true, assets);
        } else if (poolId == 1) {
            address[] memory assets = new address[](2);
            assets[0] = USDCET;
            assets[1] = USDT;
            return (true, assets);
        } else {
            address[] memory assets = new address[](0);
            return (true, assets);
        }
    }

    function getStableAssetPoolTotalSupply(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function getStableAssetPoolPrecision(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function getStableAssetPoolMintFee(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function getStableAssetPoolSwapFee(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function getStableAssetPoolRedeemFee(uint32 poolId) external view returns (bool, uint256) {
        revert("MockStableAsset: unimplement");
    }

    function stableAssetSwap(uint32 poolId, uint32 i, uint32 j, uint256 dx, uint256 minDY, uint32 assetLength)
        external
        returns (bool)
    {
        revert("MockStableAsset: unimplement");
    }

    function stableAssetMint(uint32 poolId, uint256[] calldata amounts, uint256 minMintAmount)
        external
        returns (bool)
    {
        if (poolId == 0) {
            require(amounts.length == 2, "MockStableAsset: invalid amounts length");
            uint256 dotAmount = amounts[0];
            uint256 rebasedLdotAmount = amounts[1];

            if (dotAmount == 0 && rebasedLdotAmount == 0) {
                revert("MockStableAsset: invalid amounts");
            }

            uint256 ldotAmount = rebasedLdotAmount.mul(1e18).div(IHoma(HOMA).getExchangeRate());
            MockToken(DOT).forceTransfer(msg.sender, address(this), dotAmount);
            MockToken(LDOT).forceTransfer(msg.sender, address(this), ldotAmount);

            // set DOT mint tDOT at 1:1, and LDOT mint tDOT at 1:10
            uint256 tdotAmount = dotAmount.add(ldotAmount.div(10));
            MockToken(TDOT).mint(msg.sender, tdotAmount);
        } else if (poolId == 1) {
            require(amounts.length == 2, "MockStableAsset: invalid amounts length");
            require(amounts[0] != 0 || amounts[1] != 0, "MockStableAsset: invalid amounts");

            MockToken(USDCET).forceTransfer(msg.sender, address(this), amounts[0]);
            MockToken(USDT).forceTransfer(msg.sender, address(this), amounts[1]);

            // set USDCET mint TUSD at 1:1, and USDT mint TUSD at 1:1
            uint256 tusdAmount = amounts[0].add(amounts[1]);
            MockToken(TUSD).mint(msg.sender, tusdAmount);
        } else {
            revert("MockStableAsset: invalid pool");
        }

        return true;
    }

    function stableAssetRedeem(uint32 poolId, uint256 redeemAmount, uint256[] calldata amounts)
        external
        returns (bool)
    {
        revert("MockStableAsset: unimplement");
    }

    function stableAssetRedeemSingle(
        uint32 poolId,
        uint256 redeemAmount,
        uint32 i,
        uint256 minRedeemAmount,
        uint32 assetLength
    ) external returns (bool) {
        revert("MockStableAsset: unimplement");
    }

    function stableAssetRedeemMulti(uint32 poolId, uint256[] calldata amounts, uint256 maxRedeemAmount)
        external
        returns (bool)
    {
        revert("MockStableAsset: unimplement");
    }
}
