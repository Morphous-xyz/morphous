// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IZion} from "src/interfaces/IZion.sol";

/**
 * @title Zion
 * @notice Zion is a registry for all the contracts in the system.
 * @dev This contract is used for the Multicall to know which module call.
 * @dev That module structure allows us to upgrade the system without having to redeploy the whole system.
 */
abstract contract Zion is IZion {
    // Mapping to store the contract modules in the system.
    // The key is a bytes1 identifier and the value is the contract address.
    mapping(bytes1 => address) internal modules;

    event ModuleSet(bytes1 indexed identifier, address indexed module);

    /**
     * @notice Set a module for a given identifier.
     * @param identifier The identifier of the module.
     * @param module The address of the module.
     * @dev This function can only be called by the owner of the contract.
     * If the module is already set for the identifier, it will overwrite it.
     */
    function _setModule(bytes1 identifier, address module) internal {
        modules[identifier] = module;

        // Emit the ModuleSet event after successfully setting the module.
        emit ModuleSet(identifier, module);
    }

    /**
     * @notice Get the module address for a given identifier.
     * @param identifier The identifier of the module.
     * @return The address of the module.
     * @dev This is a view function, meaning it only reads data and does not modify the contract state.
     */
    function _getModule(bytes1 identifier) internal view returns (address) {
        return modules[identifier];
    }
}
