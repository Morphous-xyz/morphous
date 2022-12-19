// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenActions} from "src/actions/TokenActions.sol";
import {MorphoRouter} from "src/actions/morpho/MorphoRouter.sol";

/// @title Morphous
/// @notice Allows interaction with the Morpho protocol for DSProxy or any delegateCall type contract.
/// @author @Mutative_
contract Morphous is MorphoRouter, TokenActions {
    /// @notice Address of this contract.
    address public immutable _MORPHEUS;

    /// @notice Checks if timestamp is not expired
    /// @param deadline Timestamp to not be expired.
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert Constants.DEADLINE_EXCEEDED();
        _;
    }

    constructor() {
        _MORPHEUS = address(this);
    }

    /// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
    /// @param deadline The time by which this function must be called before failing
    /// @param data The encoded function data for each of the calls to make to this contract
    /// @return results The results from each of the calls passed in via data
    function multicall(uint256 deadline, bytes[] calldata data)
        public
        payable
        checkDeadline(deadline)
        returns (bytes32[] memory results)
    {
        results = new bytes32[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = IDSProxy(address(this)).execute(_MORPHEUS, data[i]);
        }
    }

    receive() external payable {}
}
