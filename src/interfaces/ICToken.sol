// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface ICToken {
    function underlying() external view returns (address);
}
