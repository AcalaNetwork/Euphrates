// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin-contracts/utils/math/SafeMath.sol";
import "@AcalaNetwork/predeploy-contracts/homa/IHoma.sol";
import "./MockToken.sol";

contract MockHoma is IHoma {
    using SafeMath for uint256;

    uint256 public exchangeRate = 1e18 / 8; // 1 STAKING_TOKEN = 8 LIDUID_TOKEN
    address public immutable STAKING_TOKEN;
    address public immutable LIDUID_TOKEN;

    constructor(address stakingToken, address liquidToken) {
        STAKING_TOKEN = stakingToken;
        LIDUID_TOKEN = liquidToken;
    }

    function mint(uint256 mintAmount) external returns (bool) {
        MockToken(STAKING_TOKEN).forceTransfer(msg.sender, address(this), mintAmount);

        uint256 liquidAmount = mintAmount.mul(1e18).div(getExchangeRate());
        MockToken(LIDUID_TOKEN).mint(msg.sender, liquidAmount);
        emit Minted(msg.sender, mintAmount);
        return true;
    }

    function requestRedeem(uint256 redeemAmount, bool fastMatch) external returns (bool) {
        revert("MockHoma: unimplement");
    }

    function getExchangeRate() public view returns (uint256) {
        return exchangeRate;
    }

    function getEstimatedRewardRate() external view returns (uint256) {
        revert("MockHoma: unimplement");
    }

    function getCommissionRate() external view returns (uint256) {
        revert("MockHoma: unimplement");
    }

    function getFastMatchFee() external view returns (uint256) {
        revert("MockHoma: unimplement");
    }
}
