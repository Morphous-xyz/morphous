// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {MorphoCore} from "src/actions/morpho/MorphoCore.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice Supply a token to an MorphoRouter-Aave or MorphoRouter-Compound market.
/// @author @Mutative_
abstract contract MorphoBorrow is MorphoCore {
    using SafeTransferLib for ERC20;

    event Borrowed(address indexed token, uint256 amount);
    event BorrowedWithMaxGas(address indexed token, uint256 amount, uint256 maxGas);

    function borrow(address market, address _poolToken, uint256 _amount) external onlyValidMarket(market) {
        address _token = _getToken(market, _poolToken);
        IMorpho(market).borrow(_poolToken, _amount);

        emit Borrowed(_token, _amount);
    }

    function borrow(address market, address _poolToken, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(market)
    {
        address _token = _getToken(market, _poolToken);
        IMorpho(market).borrow(_poolToken, _amount, _maxGasForMatching);

        emit BorrowedWithMaxGas(_token, _amount, _maxGasForMatching);
    }

    function repay(address market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(market)
    {
        address _token = _getToken(market, _poolToken);

        TokenUtils._approve(_token, market, _amount);
        IMorpho(market).repay(_poolToken, _onBehalf, _amount);
    }
}
