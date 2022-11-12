// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMorpheus {
    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory results);
}
