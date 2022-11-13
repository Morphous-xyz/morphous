// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IPoolToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
