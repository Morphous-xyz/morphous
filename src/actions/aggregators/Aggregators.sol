// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice Paraswap Exchange Logic.
abstract contract Aggregators {
    using SafeTransferLib for ERC20;

    /// @notice Error when swap fails.
    error SWAP_FAILED();

    /// @notice AugustusSwapper contract address.
    address public constant AUGUSTUS = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;

    /// @notice AugustusSwapper contract address.
    address public constant INCH_ROUTER = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    /// @notice Paraswap Token pull contract address.
    address public constant TOKEN_TRANSFER_PROXY = 0x216B4B4Ba9F3e719726886d34a177484278Bfcae;

    event ExchangeAggregator(address _tokenFrom, address _tokenTo, uint256 _amountFrom, uint256 _amountTo);

    modifier onlyValidAggregator(address _aggregator) {
        _checkAggregator(_aggregator);
        _;
    }

    function exchange(
        address aggregator,
        address srcToken,
        address destToken,
        uint256 underlyingAmount,
        bytes memory callData
    ) external payable onlyValidAggregator(aggregator) returns (uint256 received) {
        bool success;
        uint256 _before =
            destToken == Constants._ETH ? address(this).balance : ERC20(destToken).balanceOf(address(this));

        if (srcToken == Constants._ETH) {
            (success,) = aggregator.call{value: underlyingAmount}(callData);
        } else {
            TokenUtils._approve(srcToken, aggregator == AUGUSTUS ? TOKEN_TRANSFER_PROXY : INCH_ROUTER, underlyingAmount);
            (success,) = aggregator.call(callData);
        }
        if (!success) revert SWAP_FAILED();

        if (destToken == Constants._ETH) {
            received = address(this).balance - _before;
        } else {
            received = ERC20(destToken).balanceOf(address(this)) - _before;
        }

        emit ExchangeAggregator(srcToken, destToken, underlyingAmount, received);
    }

    function _checkAggregator(address _aggregator) internal pure {
        if (_aggregator != AUGUSTUS && _aggregator != INCH_ROUTER) revert Constants.INVALID_AGGREGATOR();
    }
}