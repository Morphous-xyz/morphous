// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IMorpheus} from "src/interfaces/IMorpheus.sol";
import {IFlashLoanHandler} from "src/interfaces/IFlashLoan.sol";
import {ProxyPermission} from "src/ds-proxy/ProxyPermission.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";

/// @notice Free from the matrix.
/// @author @Mutative_
contract Neo is ProxyPermission {
    /// @notice Morpheus address.
    IMorpheus internal immutable _MORPHEUS;

    /// @notice Balancer Flash loan address.
    IFlashLoanHandler internal immutable _FLASH_LOAN;

    constructor(address _morpheus, address _flashLoan) {
        _MORPHEUS = IMorpheus(_morpheus);
        _FLASH_LOAN = IFlashLoanHandler(_flashLoan);
    }
    /// @notice Execute a flash loan from Balancer and call a series of actions on _Morpheus through DSProxy.
    /// @param tokens Array of tokens to flashloan.
    /// @param amounts Array of amounts to flashloan.
    /// @param data Data of actions to call on _Morpheus.

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

    /// @notice Execute a flash loan from Balancer and call a series of actions on _Morpheus through DSProxy.
    /// @param tokens Array of tokens to flashloan.
    /// @param data Data of actions to call on _Morpheus.
    /// @dev Doesn't work with ETH as it's already in the DSProxy balance with msg.value before calling Morpheus.
    function executeWithReceiver(address[] calldata tokens, bytes calldata data, address receiver) external payable {
        uint256 length = tokens.length;
        uint256[] memory balancesBefore = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            balancesBefore[i] = TokenUtils._balanceInOf(tokens[i], address(this));
        }

        // Execute flash loan.
        IDSProxy(address(this)).execute(address(_MORPHEUS), data);

        for (uint256 i = 0; i < length; i++) {
            uint256 paybackAmount = TokenUtils._balanceInOf(tokens[i], address(this)) - balancesBefore[i];
            TokenUtils._transfer(tokens[i], receiver, paybackAmount);
        }
    }

    /// @notice Execute a flash loan from Balancer and call a series of actions on _Morpheus through DSProxy.
    /// @param tokens Array of tokens to flashloan.
    /// @param amounts Array of amounts to flashloan.
    /// @param data Data of actions to call on _Morpheus.
    function executeFlashloanWithReceiver(
        address[] calldata tokensReceiver,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data,
        address receiver,
        bool isAave
    ) external payable {
        uint256 length = tokensReceiver.length;
        uint256[] memory balancesBefore = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            balancesBefore[i] = TokenUtils._balanceInOf(tokensReceiver[i], address(this));
        }

        // Give _FLASH_LOAN permission to call execute on behalf DSProxy.
        _togglePermission(address(_FLASH_LOAN), true);

        // Execute flash loan.
        _FLASH_LOAN.flashLoan(tokens, amounts, data, isAave);

        // Remove _FLASH_LOAN permission to call execute on behalf DSProxy.
        _togglePermission(address(_FLASH_LOAN), false);

        for (uint256 i = 0; i < length; i++) {
            uint256 paybackAmount = TokenUtils._balanceInOf(tokensReceiver[i], address(this)) - balancesBefore[i];
            TokenUtils._transfer(tokensReceiver[i], receiver, paybackAmount);
        }
    }

    receive() external payable {}
}
