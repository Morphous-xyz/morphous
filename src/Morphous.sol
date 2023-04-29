// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {MorphoRouter} from "src/MorphoRouter.sol";
import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenActions} from "src/actions/TokenActions.sol";

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
    /// @param argPos The position of the argument that should be updated with the previous call's return data
    /// @return results The results from each of the calls passed in via data
    function multicall(uint256 deadline, bytes[] calldata data, uint256[] calldata argPos)
        public
        payable
        checkDeadline(deadline)
        returns (bytes32[] memory results)
    {
        if (data.length != argPos.length) revert Constants.INVALID_LENGTH();

        results = new bytes32[](data.length);

        uint256 _argPos;
        uint256 _lentgh = data.length;

        for (uint256 i = 0; i < _lentgh;) {
            _argPos = argPos[i];
            if (i > 0 && _argPos > 0) {
                uint256 _argToUpdate = argPos[i];
                bytes memory _updatedData = data[i];
                uint256 _previousCallResult = uint256(results[i - 1]);

                assembly {
                    mstore(add(_updatedData, add(_argToUpdate, 0x20)), _previousCallResult)
                }

                results[i] = IDSProxy(address(this)).execute(_MORPHEUS, _updatedData);
            } else {
                results[i] = IDSProxy(address(this)).execute(_MORPHEUS, data[i]);
            }

            unchecked {
                ++i;
            }
        }
    }

    function version() external pure returns (string memory) {
        return "2.0.0";
    }

    function getLogger() external pure returns (address) {
        return _LOGGER;
    }

    receive() external payable {}
}
