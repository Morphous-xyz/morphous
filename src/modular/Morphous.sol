// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Zion} from "src/modular/Zion.sol";
import {IZion} from "src/interfaces/IZion.sol";
import {Owned} from "solmate/auth/Owned.sol";

/// @title Modular Morphous
/// @notice Allows interaction with the Morpho protocol for DSProxy or any delegateCall type contract.
/// @dev This contract interacts with a registry (Zion) to retrieve the module addresses.
/// @author @Mutative_
contract ModMorphous is Zion, Owned(msg.sender) {
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

    function getModule(bytes32 identifier) external view returns (address) {
        return _getModule(identifier);
    }

    /// @notice Sees {Zion-_setModule}.
    function setModule(bytes32 identifier, address module) external onlyOwner {
        _setModule(identifier, module);
    }

    /// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
    /// @param deadline The time by which this function must be called before failing
    /// @param data The encoded function data for each of the calls to make to this contract.
    /// Each item should contain the identifier of the module followed by the data to be passed to the module.
    /// @dev Uses the Zion contract as a registry to retrieve the module addresses.
    /// @return results The results from each of the calls passed in via data
    function multicall(uint256 deadline, bytes[] calldata data)
        public
        payable
        checkDeadline(deadline)
        returns (bytes32[] memory results)
    {
        // Initialize an array to hold the results from each of the calls
        results = new bytes32[](data.length);

        // Loop through the array of function data
        for (uint256 i = 0; i < data.length; i++) {
            // Decode the first item of the array into a module identifier and the associated function data
            (bytes32 identifier, bytes memory currentData) = abi.decode(data[i], (bytes32, bytes));

            // Must make an external call due to `multicall` being called as a delegatecall, meaning we cannot retrieve directly from storage
            address module = _ZION.getModule(identifier);

            // Use the IDSProxy contract to call the function in the module and store the result
            results[i] = IDSProxy(address(this)).execute(module, currentData);
        }
    }

    receive() external payable {}
}
