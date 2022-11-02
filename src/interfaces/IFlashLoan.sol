// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IFlashLoan {
    function flashLoan(address _receiver, address[] memory _tokens, uint256[] memory _amounts, bytes calldata _data)
        external;
}

interface IFlashLoanBalancer {
    function flashLoanBalancer(address[] memory _tokens, uint256[] memory _amounts, bytes calldata _data) external;
}
