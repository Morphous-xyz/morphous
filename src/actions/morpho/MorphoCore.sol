// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface IPoolToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

interface ICToken {
    function underlying() external view returns (address);
}

/// @notice Supply a token to an MorphoRouter-Aave or MorphoRouter-Compound _market.
/// @author @Mutative_
abstract contract MorphoCore {
    modifier onlyValidMarket(address _market) {
        if (_market != Constants._MORPHO_AAVE && _market != Constants._MORPHO_COMPOUND) {
            revert Constants.INVALID_MARKET();
        }
        _;
    }

    function _getToken(address _market, address _poolToken) internal view returns (address) {
        if (_market == Constants._MORPHO_AAVE) return IPoolToken(_poolToken).UNDERLYING_ASSET_ADDRESS();
        else if (_market == Constants._MORPHO_COMPOUND && _poolToken == Constants._cETHER) return Constants._WETH;
        else if (_market == Constants._MORPHO_COMPOUND) return ICToken(_poolToken).underlying();
        else revert Constants.INVALID_MARKET();
    }
}
