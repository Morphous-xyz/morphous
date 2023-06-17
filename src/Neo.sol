// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IMorphous} from "src/interfaces/IMorphous.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {IFlashLoanHandler} from "src/interfaces/IFlashLoan.sol";
import {ProxyPermission} from "src/ds-proxy/ProxyPermission.sol";

/// @title Neo
/// @notice Utility contract to execute flash loans and call a series of actions on Morphous through DSProxy.
/// @author @Mutative_
contract Neo is ProxyPermission {
    /// @notice Morphous address.
    IMorphous public immutable _MORPHOUS;

    /// @notice Balancer Flash loan address.
    IFlashLoanHandler public immutable _FLASH_LOAN;

    constructor(address _morphous, address _flashLoan) {
        _MORPHOUS = IMorphous(_morphous);
        _FLASH_LOAN = IFlashLoanHandler(_flashLoan);
    }

    /// @notice Execute a flash loan and call a series of actions on _Morphous through DSProxy.
    /// @param tokens Array of tokens to flashloan.
    /// @param amounts Array of amounts to flashloan.
    /// @param data Data of actions to call on _Morphous.
    function executeFlashloan(address[] calldata tokens, uint256[] calldata amounts, bytes calldata data, bool isAave)
        external
        payable
    {
        // Give _FLASH_LOAN permission to call execute on behalf DSProxy.
        _togglePermission(address(_FLASH_LOAN), true);

        // Execute flash loan.
        _FLASH_LOAN.flashLoan(tokens, amounts, data, isAave);

        // Remove _FLASH_LOAN permission to call execute on behalf DSProxy.
        _togglePermission(address(_FLASH_LOAN), false);
    }

    receive() external payable {}
}
