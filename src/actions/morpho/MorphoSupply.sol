// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";

/// @notice Supply a token to an MorphoRouter-Aave or MorphoRouter-Compound market.
/// @author @Mutative_
contract MorphoSupply {
    function supply(address market, address _poolToken, uint256 _amount) external {
        IMorpho(market).supply(_poolToken, _amount);
    }

    function supply(address market, address _poolToken, address _onBehalf, uint256 _amount) external {
        IMorpho(market).supply(_poolToken, _onBehalf, _amount);
    }

    function supply(address market, address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        external
    {
        IMorpho(market).supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);
    }
}
