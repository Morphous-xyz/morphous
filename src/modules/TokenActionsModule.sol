// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

// Importing required libraries and contracts
import {Logger} from "src/Logger.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {BaseModule} from "src/modules/BaseModule.sol";
import {TokenUtils, Constants} from "src/libraries/TokenUtils.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @title TokenActionsModule
/// @notice This contract contains functions related to token actions such as transfer and approval
contract TokenActionsModule is BaseModule {
    using SafeTransferLib for ERC20;

    /// @notice Constructs the TokenActionsModule contract
    /// @param logger The logger contract
    constructor(Logger logger) BaseModule(logger) {}

    /// @notice Approves a certain amount of token for a recipient
    /// @param _token The token to approve
    /// @param _to The address to approve the tokens for
    /// @param _amount The amount of tokens to approve
    function approveToken(address _token, address _to, uint256 _amount) external {
        TokenUtils._approve(_token, _to, _amount);
    }

    /// @notice Transfers a certain amount of tokens from one address to another
    /// @param _token The token to transfer
    /// @param _from The address to transfer the tokens from
    /// @param _amount The amount of tokens to transfer
    /// @return The actual amount transferred
    function transferFrom(address _token, address _from, uint256 _amount) external returns (uint256) {
        return TokenUtils._transferFrom(_token, _from, _amount);
    }

    /// @notice Transfers a certain amount of tokens to a recipient
    /// @param _token The token to transfer
    /// @param _to The address to transfer the tokens to
    /// @param _amount The amount of tokens to transfer
    /// @return The actual amount transferred
    function transfer(address _token, address _to, uint256 _amount) external returns (uint256) {
        return TokenUtils._transfer(_token, _to, _amount);
    }

    /// @notice Deposits a certain amount of stETH
    /// @param _amount The amount of stETH to deposit
    function depositSTETH(uint256 _amount) external {
        TokenUtils._depositSTETH(_amount);
    }

    /// @notice Deposits a certain amount of WETH
    /// @param _amount The amount of WETH to deposit
    function depositWETH(uint256 _amount) external {
        TokenUtils._depositWETH(_amount);
    }

    /// @notice Withdraws a certain amount of WETH
    /// @param _amount The amount of WETH to withdraw
    function withdrawWETH(uint256 _amount) external {
        TokenUtils._withdrawWETH(_amount);
    }

    /// @notice Gets the balance of an account for a specific token
    /// @param _token The token to check the balance for
    /// @param _acc The address to check the balance of
    /// @return The balance of the account in the token
    function balanceInOf(address _token, address _acc) public view returns (uint256) {
        return TokenUtils._balanceInOf(_token, _acc);
    }
}
