// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

/// @title Constant state
/// @notice Constant state used by the swap router
library Constants {
    /// @notice The address of Morpho Aave markets.
    address internal constant _MORPHO_AAVE = 0x777777c9898D384F785Ee44Acfe945efDFf5f3E0;

    /// @notice Address of Balancer contract.
    address internal constant _BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /// @notice The address of Morpho Compound markets.
    address internal constant _MORPHO_COMPOUND = 0x8888882f8f843896699869179fB6E4f7e3B58888;

    /// @notice Address of Paraswap contract.
    address internal constant _AUGUSTUS_SWAPPER = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;

    /// @notice Address of Factory Guard contract.
    address internal constant _FACTORY_GUARD_ADDRESS = 0x5a15566417e6C1c9546523066500bDDBc53F88C7;

    /// @dev Used for identifying cases when this contract's balance of a token is to be used
    uint256 internal constant _CONTRACT_BALANCE = 0;

    /// @dev Used as a flag for identifying msg.sender, saves gas by sending more 0 bytes
    address internal constant _MSG_SENDER = address(1);

    /// @dev Used as a flag for identifying address(this), saves gas by sending more 0 bytes
    address internal constant _ADDRESS_THIS = address(2);

    /////////////////////////////////////////////////////////////////
    /// --- ERRORS
    ////////////////////////////////////////////////////////////////

    /// @dev Error message when the caller is not allowed to call the function.
    error NOT_ALLOWED();

    /// @dev Error message when the caller is not allowed to call the function.
    error INVALID_LENDER();

    /// @dev Error message when the deadline has passed.
    error DEADLINE_EXCEEDED();

    /// @dev Error message for when the amount of received tokens is less than the minimum amount
    error NOT_ENOUGH_RECEIVED();
}
