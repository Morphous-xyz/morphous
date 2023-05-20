// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Logger} from "src/logger/Logger.sol";

/// @notice Morpho Router.
/// @author @Mutative_
abstract contract LogCore {
    /// TODO: change this address to the logger contract address, before deploying to mainnet
    Logger public constant LOGGER = Logger(0x1234567890123456789012345678901234567890);
}
