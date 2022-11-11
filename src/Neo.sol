// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IDSAuth} from "src/interfaces/IDSAuth.sol";
import {IDSGuard} from "src/interfaces/IDSGuard.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ProxyPermission} from "src/ds-proxy/ProxyPermission.sol";
import {IFlashLoanBalancer} from "src/interfaces/IFlashLoan.sol";
import {MorphoRouter} from "src/actions/morpho/MorphoRouter.sol";
import {IDSGuardFactory} from "src/interfaces/IDSGuardFactory.sol";

interface IMorpheus {
    function getMorphoRouter() external view returns (address);
    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory results);
}

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

    function executeFlashloan(address[] calldata tokens, uint256[] calldata amounts, bytes calldata data)
        external
        payable
    {
        _togglePermission(address(_FLASH_LOAN), true);

        _FLASH_LOAN.flashLoanBalancer(tokens, amounts, data);

        _togglePermission(address(_FLASH_LOAN), false);
    }

    function callBackFlashloan(uint256 deadline, bytes[] calldata data) external payable {
        IMorpheus(_MORPHEUS).multicall(deadline, data);
    }

    receive() external payable {}
}
