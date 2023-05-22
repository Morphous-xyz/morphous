// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IZion} from "src/interfaces/IZion.sol";
import {Zion} from "src/Zion.sol";
import {Owned} from "solmate/auth/Owned.sol";

/// @title Morphous
/// @notice Allows interaction with the Morpho protocol for DSProxy or any delegateCall type contract.
/// @author @Mutative_
contract Morphous is Zion, Owned(msg.sender) {
    /// @notice Address of this contract.
    IZion internal immutable _ZION;

    /// @notice Checks if timestamp is not expired
    /// @param deadline Timestamp to not be expired.
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert Constants.DEADLINE_EXCEEDED();
        _;
    }

    constructor() {
        _ZION = IZion(address(this));
    }

    ////////////////////////////////////////////////////////////////
    /// --- Zion functions
    ///////////////////////////////////////////////////////////////

    function getModule(bytes1 identifier) external view returns (address) {
        return _getModule(identifier);
    }

    /// @notice Sees {Zion-_setModule}.
    function setModule(bytes1 identifier, address module) external onlyOwner {
        _setModule(identifier, module);
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
        uint256 _length = data.length;

        for (uint256 i = 0; i < _length;) {
            // Decode the first item of the array into a module identifier and the associated function data
            (bytes1 _moduleIdentifier, bytes memory _moduleData) = abi.decode(data[i], (bytes1, bytes));

            // Must make an external call due to `multicall` being called as a delegatecall, meaning we cannot retrieve directly from storage
            address module = _ZION.getModule(_moduleIdentifier);

            _argPos = argPos[i];

            if (i > 0 && _argPos > 0) {
                uint256 _argToUpdate = argPos[i];
                bytes memory _updatedData = _moduleData;
                uint256 _previousCallResult = uint256(results[i - 1]);

                assembly {
                    mstore(add(_updatedData, add(_argToUpdate, 0x20)), _previousCallResult)
                }

                results[i] = IDSProxy(address(this)).execute(module, _updatedData);
            } else {
                results[i] = IDSProxy(address(this)).execute(module, _moduleData);
            }

            unchecked {
                ++i;
            }
        }
    }

    function version() external pure returns (string memory) {
        return "2.0.0";
    }

    receive() external payable {}
}
