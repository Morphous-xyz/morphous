// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMorpho {
    function supply(address _poolToken, uint256 _amount) external;
    function supply(address _poolToken, address _onBehalf, uint256 _amount) external;
    function supply(address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching) external;

    function withdraw(address _poolToken, uint256 _amount) external;
    function withdraw(address _poolToken, uint256 _amount, address _receiver) external;
}
