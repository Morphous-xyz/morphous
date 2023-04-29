// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {LogCore} from "src/logger/LogCore.sol";
import {IMorpho} from "src/interfaces/IMorpho.sol";
import {ICToken} from "src/interfaces/ICToken.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {IPoolToken} from "src/interfaces/IPoolToken.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice Supply a token to an MorphoRouter-Aave or MorphoRouter-Compound _market.
/// @author @Mutative_
abstract contract MorphoCore is LogCore {
    modifier onlyValidMarket(address _market) {
        if (
            _market != Constants._MORPHO_AAVE && _market != Constants._MORPHO_COMPOUND
                && _market != Constants._MORPHO_AAVE_V3
        ) {
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
