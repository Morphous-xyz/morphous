// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IDSAuth} from "src/interfaces/IDSAuth.sol";
import {IDSGuard} from "src/interfaces/IDSGuard.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IDSGuardFactory} from "src/interfaces/IDSGuardFactory.sol";

abstract contract ProxyPermission {
    /// @notice DSProxy execute function signature.
    bytes4 internal constant _EXECUTE_SELECTOR = bytes4(keccak256("execute(address,bytes)"));

    /// @notice Called in the context of DSProxy to authorize an address to call on behalf of the DSProxy.
    /// @param _target Address which will be authorized
    function _togglePermission(address _target, bool _give) internal {
        address currAuthority = address(IDSAuth(address(this)).authority());
        IDSGuard guard = IDSGuard(currAuthority);

        if (currAuthority == address(0)) {
            guard = IDSGuard(IDSGuardFactory(Constants._FACTORY_GUARD_ADDRESS).newGuard());
            IDSAuth(address(this)).setAuthority(address(guard));
        }

        if (_give && !guard.canCall(_target, address(this), _EXECUTE_SELECTOR)) {
            guard.permit(_target, address(this), _EXECUTE_SELECTOR);
        } else if (!_give && guard.canCall(_target, address(this), _EXECUTE_SELECTOR)) {
            guard.forbid(_target, address(this), _EXECUTE_SELECTOR);
        }
    }
}
