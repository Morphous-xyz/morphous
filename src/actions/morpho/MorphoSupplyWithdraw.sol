// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {MorphoCore} from "src/actions/morpho/MorphoCore.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice Supply a token to an MorphoRouter-Aave or MorphoRouter-Compound market.
/// @author @Mutative_
abstract contract MorphoSupplyWithdraw is MorphoCore {
    using SafeTransferLib for ERC20;

    event SuppliedOnBehalf(address indexed token, uint256 amount, address indexed onBehalfOf);
    event SuppliedWithMaxGas(address indexed token, uint256 amount, address indexed onBehalOf, uint256 maxGas);

    event Withdrawn(address indexed token, uint256 amount);

    function supply(address market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(market)
    {
        address _token = _getToken(market, _poolToken);

        TokenUtils._approve(_token, market, _amount);
        IMorpho(market).supply(_poolToken, _onBehalf, _amount);

        emit SuppliedOnBehalf(_poolToken, _amount, _onBehalf);
    }

    function supply(address market, address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(market)
    {
        address _token = _getToken(market, _poolToken);

        TokenUtils._approve(_token, market, _amount);
        IMorpho(market).supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);

        emit SuppliedWithMaxGas(_poolToken, _amount, _onBehalf, _maxGasForMatching);
    }

    function withdraw(address market, address _poolToken, uint256 _amount) external onlyValidMarket(market) {
        IMorpho(market).withdraw(_poolToken, _amount);

        emit Withdrawn(_poolToken, _amount);
    }
}
