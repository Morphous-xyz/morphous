// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Constants} from "src/libraries/Constants.sol";
import {IMorpheus} from "src/interfaces/IMorpheus.sol";
import {ProxyPermission} from "src/ds-proxy/ProxyPermission.sol";
import {IFlashLoanBalancer} from "src/interfaces/IFlashLoan.sol";

/// @notice Free from the matrix.
/// @author @Mutative_
contract Neo is ProxyPermission {
    /// @notice Morpheus address.
    IMorpheus internal immutable _MORPHEUS;

    /// @notice Balancer Flash loan address.
    IFlashLoanBalancer internal immutable _FLASH_LOAN;

    constructor(address _morpheus, address _flashLoan) {
        _MORPHEUS = IMorpheus(_morpheus);
        _FLASH_LOAN = IFlashLoanBalancer(_flashLoan);
    }

    /// @notice Execute a flash loan from Balancer and call a series of actions on _Morpheus through DSProxy.
    /// @param tokens Array of tokens to flashloan.
    /// @param amounts Array of amounts to flashloan.
    /// @param data Data of actions to call on _Morpheus.
    function executeFlashloan(address[] calldata tokens, uint256[] calldata amounts, bytes calldata data)
        external
        payable
    {
        // Give _FLASH_LOAN permission to call execute on behalf DSProxy.
        _togglePermission(address(_FLASH_LOAN), true);

        // Execute flash loan.
        _FLASH_LOAN.flashLoanBalancer(tokens, amounts, data);

        // Remove _FLASH_LOAN permission to call execute on behalf DSProxy.
        _togglePermission(address(_FLASH_LOAN), false);
    }

    receive() external payable {}
}
