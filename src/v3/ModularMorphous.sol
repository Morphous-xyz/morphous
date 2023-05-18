// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IZion} from "src/v3/interfaces/IZion.sol";

/// @title Morphous
/// @notice Allows interaction with the Morpho protocol for DSProxy or any delegateCall type contract.
/// @author @Mutative_
contract ModularMorphous {
    /// @notice Address of this contract.
    IZion public immutable _ZION;

    /// @notice Checks if timestamp is not expired
    /// @param deadline Timestamp to not be expired.
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert Constants.DEADLINE_EXCEEDED();
        _;
    }

    constructor(IZion _zion) {
        _ZION = _zion;
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

            // Use the Zion contract to retrieve the module address for the given identifier
            address module = _ZION.getModule(identifier);

            // Use the IDSProxy contract to call the function in the module and store the result
            results[i] = IDSProxy(address(this)).execute(module, currentData);
        }
    }

    receive() external payable {}
}
