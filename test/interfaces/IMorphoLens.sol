// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMorphoLens {
    function getCurrentSupplyBalanceInOf(address _token, address _user)
        external
        view
        returns (uint256, uint256, uint256);

    function getCurrentBorrowBalanceInOf(address _token, address _user)
        external
        view
        returns (uint256, uint256, uint256);
}
