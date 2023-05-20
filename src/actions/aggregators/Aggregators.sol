// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {LogCore} from "src/logger/LogCore.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice Contract that allows to swap tokens through different aggregators.
abstract contract Aggregators is LogCore {
    using SafeTransferLib for ERC20;

    /// @notice Error when swap fails.
    error SWAP_FAILED();

    /// @notice AugustusSwapper contract address.
    address public constant ZERO_EX_ROUTER = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    /// @notice 1nch Router v5 contract address.
    address public constant INCH_ROUTER = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    modifier onlyValidAggregator(address _aggregator) {
        if (_aggregator != ZERO_EX_ROUTER && _aggregator != INCH_ROUTER) revert Constants.INVALID_AGGREGATOR();
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
        uint256 before = destToken == Constants._ETH ? address(this).balance : ERC20(destToken).balanceOf(address(this));

        if (srcToken == Constants._ETH) {
            (success,) = aggregator.call{value: underlyingAmount}(callData);
        } else {
            TokenUtils._approve(srcToken, aggregator, underlyingAmount);
            (success,) = aggregator.call(callData);
        }
        if (!success) revert SWAP_FAILED();

        if (destToken == Constants._ETH) {
            received = address(this).balance - before;
        } else {
            received = ERC20(destToken).balanceOf(address(this)) - before;
        }

        LOGGER.logExchangeAggregator(srcToken, destToken, underlyingAmount, received);
    }
}
