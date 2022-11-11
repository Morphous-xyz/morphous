// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Augustus} from "src/actions/paraswap/Augustus.sol";
import {MorphoBorrow} from "src/actions/morpho/MorphoBorrow.sol";
import {MorphoClaimRewards} from "src/actions/morpho/MorphoClaimRewards.sol";
import {MorphoSupplyWithdraw} from "src/actions/morpho/MorphoSupplyWithdraw.sol";

/// @notice Supply a token to an MorphoRouter-Aave or MorphoRouter-Compound _market.
/// @author @Mutative_
abstract contract MorphoRouter is Augustus, MorphoBorrow, MorphoClaimRewards, MorphoSupplyWithdraw {}
