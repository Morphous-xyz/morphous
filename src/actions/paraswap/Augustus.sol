// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice Paraswap Exchange Logic.
abstract contract Augustus {
    using SafeTransferLib for ERC20;

    /// @notice Error when swap fails.
    error SWAP_FAILED();

    /// @notice AugustusSwapper contract address.
    address public constant AUGUSTUS = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;

    /// @notice Paraswap Token pull contract address.
    address public constant TOKEN_TRANSFER_PROXY = 0x216B4B4Ba9F3e719726886d34a177484278Bfcae;

    event ExchangeParaswap(address _tokenFrom, address _tokenTo, uint256 _amountFrom, uint256 _amountTo);

    function exchange(address srcToken, address destToken, uint256 underlyingAmount, bytes memory callData)
        external
        payable
        returns (uint256 received)
    {
        bool success;

        uint256 _before =
            destToken == Constants._ETH ? address(this).balance : ERC20(destToken).balanceOf(address(this));

        if (srcToken == Constants._ETH) {
            (success,) = AUGUSTUS.call{value: underlyingAmount}(callData);
        } else {
            TokenUtils._approve(srcToken, TOKEN_TRANSFER_PROXY, underlyingAmount);
            (success,) = AUGUSTUS.call(callData);
        }
        if (!success) revert SWAP_FAILED();

        if (destToken == Constants._ETH) {
            received = address(this).balance - _before;
        } else {
            received = ERC20(destToken).balanceOf(address(this)) - _before;
        }

        emit ExchangeParaswap(srcToken, destToken, underlyingAmount, received);
    }
}
