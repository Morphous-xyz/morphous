// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {IFlashLoan} from "src/interfaces/IFlashLoan.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IFlashLoanRecipient} from "src/interfaces/IFlashLoanRecipient.sol";

contract FL is ReentrancyGuard, IFlashLoanRecipient {
    address public immutable MORPHOUS;

    constructor(address morpheus) {
        MORPHOUS = morpheus;
    }

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

    /// @notice Balancer FL callback function that executes _userData logic through Morphous.
    function receiveFlashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _feeAmounts,
        bytes memory _userData
    ) external override nonReentrant {
        if (msg.sender != Constants._BALANCER_VAULT) revert Constants.INVALID_LENDER();

        (address proxy, uint256 deadline, bytes[] memory data) = abi.decode(_userData, (address, uint256, bytes[]));

        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenUtils._transfer(_tokens[i], proxy, _amounts[i]);
        }

        IDSProxy(proxy).execute{value: address(this).balance}(
            MORPHOUS, abi.encodeWithSignature("multicall(uint256,bytes[])", deadline, data)
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenUtils._transfer(_tokens[i], Constants._BALANCER_VAULT, _amounts[i] + _feeAmounts[i]);
        }
    }

    /// @notice Aave FL callback function that executes _userData logic through Morphous.
    function executeOperation(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _feeAmounts,
        address _initiator,
        bytes memory _userData
    ) external override nonReentrant returns (bool) {
        if (_initiator != address(this)) revert Constants.INVALID_INITIATOR();
        if (msg.sender != Constants._AAVE_LENDING_POOL) revert Constants.INVALID_LENDER();

        (address proxy, uint256 deadline, bytes[] memory data) = abi.decode(_userData, (address, uint256, bytes[]));

        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenUtils._transfer(_tokens[i], proxy, _amounts[i]);
        }

        IDSProxy(proxy).execute{value: address(this).balance}(
            MORPHOUS, abi.encodeWithSignature("multicall(uint256,bytes[])", deadline, data)
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenUtils._approve(_tokens[i], Constants._AAVE_LENDING_POOL, _amounts[i] + _feeAmounts[i]);
        }

        return true;
    }
}
