// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @title Locker Handler
/// @notice Handle deposit into Liquid Lockers.
abstract contract Augustus {
    using SafeTransferLib for ERC20;

    /// @notice Error when swap fails.
    error SWAP_FAILED();

    /// @notice Error when slippage is too high.
    error NOT_ENOUGHT_RECEIVED();

    /// @notice AugustusSwapper contract address.
    address public constant AUGUSTUS = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;

    /// @notice Paraswap Token pull contract address.
    address public constant TOKEN_TRANSFER_PROXY = 0x216B4B4Ba9F3e719726886d34a177484278Bfcae;

    event ExchangeParaswap(
        address indexed _from,
        address indexed _to,
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountFrom,
        uint256 _amountTo
    );

    function exchange(
        address srcToken,
        address destToken,
        uint256 underlyingAmount,
        bytes memory callData,
        address recipient
    ) external payable returns (uint256 received) {
        bool success;
        if (srcToken == Constants._ETH) {
            (success,) = AUGUSTUS.call{value: underlyingAmount}(callData);
        } else {
            TokenUtils._approve(srcToken, TOKEN_TRANSFER_PROXY, underlyingAmount);
            (success,) = AUGUSTUS.call(callData);
        }
        if (!success) revert SWAP_FAILED();

        if (recipient == Constants._MSG_SENDER) {
            recipient = msg.sender;

            if (destToken == Constants._ETH) {
                received = address(this).balance;
                SafeTransferLib.safeTransferETH(recipient, received);
            } else {
                received = ERC20(destToken).balanceOf(address(this));
                TokenUtils._transfer(destToken, recipient, received);
            }
        }
        emit ExchangeParaswap(msg.sender, recipient, srcToken, destToken, underlyingAmount, received);
    }
}
