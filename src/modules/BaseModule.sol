// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Logger} from "src/logger/Logger.sol";
import {Owned} from "solmate/auth/Owned.sol";

/// @title BaseModule
/// @notice BaseModule contract.
/// @author @Mutative_
abstract contract BaseModule is Owned(msg.sender) {
    /// @notice Logger contract.
    Logger immutable LOGGER;

    /// @notice BaseModule constructor.
    constructor(Logger logger) {
        LOGGER = Logger(logger);
    }
}
