// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Augustus} from "src/actions/paraswap/Augustus.sol";
import {MorphoBorrowRepay} from "src/actions/morpho/MorphoBorrowRepay.sol";
import {MorphoClaimRewards} from "src/actions/morpho/MorphoClaimRewards.sol";
import {MorphoSupplyWithdraw} from "src/actions/morpho/MorphoSupplyWithdraw.sol";

/// @notice Morpho Router.
/// @author @Mutative_
abstract contract MorphoRouter is Augustus, MorphoBorrowRepay, MorphoClaimRewards, MorphoSupplyWithdraw {}
