// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

interface IMorphoLens {
    function getCurrentSupplyBalanceInOf(address _token, address _user)
        external
        view
        returns (uint256, uint256, uint256);

    function getCurrentBorrowBalanceInOf(address _token, address _user)
        external
        view
        returns (uint256, uint256, uint256);

    function collateralBalance(address, address) external view returns (uint256);
    function supplyBalance(address, address) external view returns (uint256);
    function borrowBalance(address, address) external view returns (uint256);
}
