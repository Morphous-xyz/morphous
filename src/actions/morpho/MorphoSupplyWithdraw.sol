// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Logger} from "src/logger/Logger.sol";
import {IMorpho} from "src/interfaces/IMorpho.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {MorphoCore} from "src/actions/morpho/MorphoCore.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice Supply a token to an MorphoRouter-Aave or MorphoRouter-Compound _market.
/// @author @Mutative_
abstract contract MorphoSupplyWithdraw is MorphoCore {
    using SafeTransferLib for ERC20;

    ////////////////////////////////////////////////////////////////
    /// --- V2
    ///////////////////////////////////////////////////////////////

    function supply(address _market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).supply(_poolToken, _onBehalf, _amount);

        LOGGER.logSupply(_poolToken, _onBehalf, _amount);
    }

    function supply(address _market, address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);

        LOGGER.logSupply(_poolToken, _onBehalf, _amount, _maxGasForMatching);
    }

    function withdraw(address _market, address _poolToken, uint256 _amount) external onlyValidMarket(_market) {
        IMorpho(_market).withdraw(_poolToken, _amount);

        LOGGER.logWithdraw(_poolToken, _amount);
    }

    ////////////////////////////////////////////////////////////////
    /// --- V3
    ///////////////////////////////////////////////////////////////
}
