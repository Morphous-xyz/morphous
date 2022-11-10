// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface IPoolToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

/// @notice Supply a token to an MorphoRouter-Aave or MorphoRouter-Compound market.
/// @author @Mutative_
abstract contract MorphoSupplyWithdraw {
    using SafeTransferLib for ERC20;

    event SuppliedOnBehalf(address indexed token, uint256 amount, address indexed onBehalfOf);
    event SuppliedWithMaxGas(address indexed token, uint256 amount, address indexed onBehalOf, uint256 maxGas);

    event Withdrawn(address indexed token, uint256 amount);
    event WithdrawnFor(address indexed token, uint256 amount, address indexed receiver);

    modifier onlyValidMarket(address market) {
        if (market != Constants._MORPHO_AAVE && market != Constants._MORPHO_COMPOUND) revert Constants.INVALID_MARKET();
        _;
    }

    function supply(address market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(market)
    {
        address _token = IPoolToken(_poolToken).UNDERLYING_ASSET_ADDRESS();

        ERC20(_token).safeApprove(market, _amount);
        IMorpho(market).supply(_poolToken, _onBehalf, _amount);

        emit SuppliedOnBehalf(_poolToken, _amount, _onBehalf);
    }

    function supply(address market, address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(market)
    {
        IMorpho(market).supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);

        emit SuppliedWithMaxGas(_poolToken, _amount, _onBehalf, _maxGasForMatching);
    }

    function withdraw(address market, address _poolToken, uint256 _amount) external onlyValidMarket(market) {
        IMorpho(market).withdraw(_poolToken, _amount);

        emit Withdrawn(_poolToken, _amount);
    }
}
