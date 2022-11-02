// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IFlashLoan} from "src/interfaces/IFlashLoan.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IFlashLoanRecipient} from "src/interfaces/IFlashLoanRecipient.sol";

contract BalancerFL is ReentrancyGuard, IFlashLoanRecipient {
    using SafeTransferLib for ERC20;

    function flashLoanBalancer(address[] memory _tokens, uint256[] memory _amounts, bytes calldata _data) external {
        IFlashLoan(Constants._BALANCER_VAULT).flashLoan(address(this), _tokens, _amounts, _data);
    }

    /// @notice Balancer FL callback function that formats and calls back RecipeExecutor
    function receiveFlashLoan(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _feeAmounts,
        bytes memory _userData
    ) external override nonReentrant {
        if (msg.sender != Constants._BALANCER_VAULT) revert Constants.INVALID_LENDER();

        (address neo, address proxy, uint256 deadline, bytes[] memory data) =
            abi.decode(_userData, (address, address, uint256, bytes[]));

        IDSProxy(proxy).execute{value: address(this).balance}(
            neo, abi.encodeWithSignature("executeAfterFlashLoan(uint256,bytes[])", deadline, data)
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 paybackAmount = _amounts[i] + _feeAmounts[i];
            ERC20(_tokens[i]).safeTransfer(Constants._BALANCER_VAULT, paybackAmount);
        }
    }
}
