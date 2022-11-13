// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {MorphoCore} from "src/actions/morpho/MorphoCore.sol";
import {IRewardsDistributor} from "src/interfaces/IRewardsDistributor.sol";

abstract contract MorphoClaimRewards is MorphoCore {
    /// @notice Rewards Distributor to claim $MORPHO token.
    address internal constant _REWARDS_DISTRIBUTOR = 0x3B14E5C73e0A56D607A8688098326fD4b4292135;

    event RewardClaimed(uint256 _claimable);
    event MorphoClaimed(address _account, uint256 _claimable);

    function claim(address _account, uint256 _claimable, bytes32[] calldata _proof) external {
        IRewardsDistributor(_REWARDS_DISTRIBUTOR).claim(_account, _claimable, _proof);

        emit MorphoClaimed(_account, _claimable);
    }

    function claim(address _market, address[] calldata _poolTokens, bool _tradeForMorphoToken)
        external
        onlyValidMarket(_market)
    {
        uint256 _claimed = IMorpho(_market).claimRewards(_poolTokens, _tradeForMorphoToken);

        emit RewardClaimed(_claimed);
    }
}
