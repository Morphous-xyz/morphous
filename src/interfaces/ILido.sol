// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

interface ILido {
    function wrap(uint256 _amount) external returns (uint256);
    function unwrap(uint256 _amount) external returns (uint256);

    function submit(address _referral) external payable;

    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
}
