// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface MakerRegistry {
    function build() external returns (address proxy);
}

interface IPoolToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

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

interface ILido {
    function submit(address _referral) external payable;
}
