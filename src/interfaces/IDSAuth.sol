// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

interface IDSAuth {
    function setAuthority(address _authority) external;
    function authority() external view returns (address);
    function isAuthorized(address src, bytes4 sig) external view returns (bool);
}
