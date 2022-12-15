// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IMorpheus} from "src/interfaces/IMorpheus.sol";
import {IFlashLoan} from "src/interfaces/IFlashLoan.sol";
import {TokenActions} from "src/actions/TokenActions.sol";
import {IFlashLoanHandler} from "src/interfaces/IFlashLoan.sol";
import {ProxyPermission} from "src/ds-proxy/ProxyPermission.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

/// @notice Free from the matrix.
/// @author @Mutative_
contract Shifter is ProxyPermission, ReentrancyGuard, TokenActions {
    /// @notice Morpheus address.
    IMorpheus internal immutable _MORPHEUS;

    /// @notice Balancer Flash loan address.
    IFlashLoanHandler internal immutable _FLASH_LOAN;

    address internal immutable _SHIFTER;

    constructor(address _morpheus, address _flashLoan) {
        _MORPHEUS = IMorpheus(_morpheus);
        _FLASH_LOAN = IFlashLoanHandler(_flashLoan);

        _SHIFTER = address(this);
    }

    /// @notice Execute a flash loan from Balancer and call a series of actions on _Morpheus through DSProxy.
    function shift(
        address[] calldata suppliedTokens,
        uint256[] calldata suppliedAmounts,
        address[] calldata borrowedTokens,
        address market
    ) external payable {
        // Give _SHIFTER permission to call execute on behalf DSProxy.
        _togglePermission(address(_SHIFTER), true);

        bytes memory data = abi.encode(address(this), borrowedTokens, market);

        // Execute flash loan.
        IFlashLoanHandler(_SHIFTER).flashLoan(suppliedTokens, suppliedAmounts, data, true);

        // Remove _FLASH_LOAN permission to call execute on behalf DSProxy.
        _togglePermission(address(_SHIFTER), false);
    }

    /// @notice Aave FL callback function that executes _userData logic through Morpheus.
    function executeOperation(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _feeAmounts,
        address _initiator,
        bytes memory _userData
    ) external nonReentrant returns (bool) {
        if (_initiator != address(this)) revert Constants.INVALID_INITIATOR();
        if (msg.sender != Constants._AAVE_LENDING_POOL) revert Constants.INVALID_LENDER();

        (address proxy, address[] memory borrowedTokens, address market) =
            abi.decode(_userData, (address, address[], address));

        for (uint256 i = 0; i < _tokens.length; i++) {
            transfer(_tokens[i], proxy, _amounts[i]);
            uint256 paybackAmount = _amounts[i] + _feeAmounts[i];

            IDSProxy(proxy).execute{value: address(this).balance}(
                _SHIFTER,
                abi.encodeWithSignature("transfer(address,address,uint256)", _tokens[i], _SHIFTER, paybackAmount)
            );

            approveToken(_tokens[i], Constants._AAVE_LENDING_POOL, paybackAmount);
        }

        return true;
    }

    function flashLoan(address[] memory _tokens, uint256[] memory _amounts, bytes calldata _data, bool) external {
        uint256[] memory modes = new uint256[](_tokens.length);
        IFlashLoan(Constants._AAVE_LENDING_POOL).flashLoan(
            address(this), _tokens, _amounts, modes, address(this), _data, 0
        );
    }

    receive() external payable {}
}
