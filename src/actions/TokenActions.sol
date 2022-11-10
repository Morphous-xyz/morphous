// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IWETH} from "src/interfaces/IWETH.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

abstract contract TokenActions {
    using SafeTransferLib for ERC20;

    address internal constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function approveToken(address _token, address _to, uint256 _amount) public {
        if (_token == _ETH) return;

        if (ERC20(_token).allowance(address(this), _to) < _amount) {
            ERC20(_token).safeApprove(_to, _amount);
        }
    }

    function transferFrom(address _token, address _from, uint256 _amount) public returns (uint256) {
        // handle max uint amount
        if (_amount == type(uint256).max) {
            _amount = balanceInOf(_token, _from);
        }

        if (_from != address(0) && _from != address(this) && _token != _ETH && _amount != 0) {
            ERC20(_token).safeTransferFrom(_from, address(this), _amount);
        }

        return _amount;
    }

    function transfer(address _token, address _to, uint256 _amount) public returns (uint256) {
        if (_amount == type(uint256).max) {
            _amount = balanceInOf(_token, address(this));
        }

        if (_to != address(0) && _to != address(this) && _amount != 0) {
            if (_token != _ETH) {
                ERC20(_token).safeTransfer(_to, _amount);
            } else {
                SafeTransferLib.safeTransferETH(_to, _amount);
            }
        }

        return _amount;
    }

    function depositWETH(uint256 _amount) public {
        IWETH(_WETH).deposit{value: _amount}();
    }

    function withdrawWETH(uint256 _amount) public {
        IWETH(_WETH).withdraw(_amount);
    }

    function balanceInOf(address _token, address _acc) public view returns (uint256) {
        if (_token == _ETH) {
            return _acc.balance;
        } else {
            return ERC20(_token).balanceOf(_acc);
        }
    }
}
