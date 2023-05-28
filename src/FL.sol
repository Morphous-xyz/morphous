// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {IFlashLoan} from "src/interfaces/IFlashLoan.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IFlashLoanRecipient} from "src/interfaces/IFlashLoanRecipient.sol";

/// @title FlashLoan contract for Aave and Balancer flash loans
/// @notice This contract allows for flash loans from Aave and Balancer, as well as executing arbitrary transactions via a DSProxy contract.
/// @author @Mutative_
contract FL is ReentrancyGuard, IFlashLoanRecipient {
    /// @notice Address of the MORPHOUS contract
    /// @dev This is immutable and set during contract deployment
    address public immutable MORPHOUS;

    /// @notice Contract constructor that sets the MORPHOUS contract address
    /// @param morpheus The address of the MORPHOUS contract
    constructor(address morpheus) {
        MORPHOUS = morpheus;
    }

    /// @notice Initiates a flash loan from either Aave or Balancer
    /// @param _tokens Array of token addresses for the flash loan
    /// @param _amounts Array of amounts for each token to be borrowed
    /// @param _data Additional data to be passed to the callback function
    /// @param isAave If true, the flash loan is taken from Aave, otherwise from Balancer
    function flashLoan(address[] memory _tokens, uint256[] memory _amounts, bytes calldata _data, bool isAave)
        external
    {
        if (isAave) {
            uint256[] memory modes = new uint256[](_tokens.length);
            IFlashLoan(Constants._AAVE_LENDING_POOL).flashLoan(
                address(this), _tokens, _amounts, modes, address(this), _data, 0
            );
        } else {
            IFlashLoan(Constants._BALANCER_VAULT).flashLoan(address(this), _tokens, _amounts, _data);
        }
    }

    /// @notice The callback function for Balancer flash loans
    /// @dev This function executes arbitrary logic through the MORPHOUS contract
    /// @param _tokens Array of token addresses for the flash loan
    /// @param _amounts Array of amounts for each token borrowed
    /// @param _feeAmounts Array of fees for each token borrowed
    /// @param _userData Additional data for execution
    function receiveFlashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _feeAmounts,
        bytes memory _userData
    ) external override nonReentrant {
        if (msg.sender != Constants._BALANCER_VAULT) revert Constants.INVALID_LENDER();

        (address proxy, uint256 deadline, bytes[] memory data, uint256[] memory argPos) =
            abi.decode(_userData, (address, uint256, bytes[], uint256[]));

        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenUtils._transfer(_tokens[i], proxy, _amounts[i]);
        }

        IDSProxy(proxy).execute{value: address(this).balance}(
            MORPHOUS, abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", deadline, data, argPos)
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenUtils._transfer(_tokens[i], Constants._BALANCER_VAULT, _amounts[i] + _feeAmounts[i]);
        }
    }

    /// @notice The callback function for Aave flash loans
    /// @dev This function executes arbitrary logic through the MORPHOUS contract
    /// @param _tokens Array of token addresses for the flash loan
    /// @param _amounts Array of amounts for each token borrowed
    /// @param _feeAmounts Array of fees for each token borrowed
    /// @param _initiator Address of the initiator of the flash loan
    /// @param _userData Additional data for execution
    /// @return Returns true if the execution was successful
    function executeOperation(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _feeAmounts,
        address _initiator,
        bytes memory _userData
    ) external override nonReentrant returns (bool) {
        if (_initiator != address(this)) revert Constants.INVALID_INITIATOR();
        if (msg.sender != Constants._AAVE_LENDING_POOL) revert Constants.INVALID_LENDER();

        (address proxy, uint256 deadline, bytes[] memory data, uint256[] memory argPos) =
            abi.decode(_userData, (address, uint256, bytes[], uint256[]));

        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenUtils._transfer(_tokens[i], proxy, _amounts[i]);
        }

        IDSProxy(proxy).execute{value: address(this).balance}(
            MORPHOUS, abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", deadline, data, argPos)
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenUtils._approve(_tokens[i], Constants._AAVE_LENDING_POOL, _amounts[i] + _feeAmounts[i]);
        }

        return true;
    }
}
