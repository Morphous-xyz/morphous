// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {MorphoCore} from "src/actions/morpho/MorphoCore.sol";

/// @notice Borrow a token from a MorphoRouter-Aave or MorphoRouter-Compound _market.
/// @author @Mutative_
abstract contract MorphoBorrowRepay is MorphoCore {
    function borrow(address _market, address _poolToken, uint256 _amount) external onlyValidMarket(_market) {
        address _token = _getToken(_market, _poolToken);
        IMorpho(_market).borrow(_poolToken, _amount);

        LOGGER.logBorrow(_token, _amount);
    }

    function borrow(address _market, address _poolToken, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);
        IMorpho(_market).borrow(_poolToken, _amount, _maxGasForMatching);

        LOGGER.logBorrow(_token, _amount, _maxGasForMatching);
    }

    function repay(address _market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).repay(_poolToken, _onBehalf, _amount);

        LOGGER.logRepay(_token, _onBehalf, _amount);
    }
}
