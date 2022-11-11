// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMorpho {
    function supply(address _poolToken, uint256 _amount) external;
    function supply(address _poolToken, address _onBehalf, uint256 _amount) external;
    function supply(address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching) external;

    function withdraw(address _poolToken, uint256 _amount) external;
    function withdraw(address _poolToken, uint256 _amount, address _receiver) external;

    function borrow(address _poolToken, uint256 _amount) external;
    function borrow(address _poolToken, uint256 _maxGasForMatching, uint256 _amount) external;

    function repay(address _poolToken, address _onBehalf, uint256 _amount) external;

    function claimRewards(address[] calldata _poolTokens, bool _tradeForMorphoToken) external returns (uint256);
}
