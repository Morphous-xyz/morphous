// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IRewardsDistributor {
    function claim(address _account, uint256 _claimable, bytes32[] calldata _proof) external;
}
