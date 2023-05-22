// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseModule} from "src/modules/BaseModule.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {Logger} from "src/logger/Logger.sol";
import {TokenUtils, Constants} from "src/libraries/TokenUtils.sol";

contract TokenActionsModule is BaseModule {
    using SafeTransferLib for ERC20;

    constructor(Logger logger) BaseModule(logger) {}

    function approveToken(address _token, address _to, uint256 _amount) external {
        TokenUtils._approve(_token, _to, _amount);
    }

    function transferFrom(address _token, address _from, uint256 _amount) external returns (uint256) {
        return TokenUtils._transferFrom(_token, _from, _amount);
    }

    function transfer(address _token, address _to, uint256 _amount) external returns (uint256) {
        return TokenUtils._transfer(_token, _to, _amount);
    }

    function depositSTETH(uint256 _amount) external {
        TokenUtils._depositSTETH(_amount);
    }

    function depositWETH(uint256 _amount) external {
        TokenUtils._depositWETH(_amount);
    }

    function withdrawWETH(uint256 _amount) external {
        TokenUtils._withdrawWETH(_amount);
    }

    function balanceInOf(address _token, address _acc) public view returns (uint256) {
        return TokenUtils._balanceInOf(_token, _acc);
    }
}
