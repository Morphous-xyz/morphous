// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {ILido} from "src/interfaces/ILido.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IPoolToken} from "src/interfaces/IPoolToken.sol";
import {IMorphoLens} from "test/interfaces/IMorphoLens.sol";
import {IMakerRegistry} from "test/interfaces/IMakerRegistry.sol";

abstract contract Utils is Test {
    address internal constant _stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    function _dealSteth(uint256 _amount) internal {
        ILido(_stETH).submit{value: _amount}(address(this));
    }

    function getQuote(address srcToken, address dstToken, uint256 amount, string memory side)
        internal
        returns (uint256 _quote, bytes memory data)
    {
        string[] memory inputs = new string[](6);
        inputs[0] = "python3";
        inputs[1] = "test/utils/python/get_quote_0x.py";
        inputs[2] = vm.toString(srcToken);
        inputs[3] = vm.toString(dstToken);
        inputs[4] = vm.toString(amount);
        inputs[5] = side;

        return abi.decode(vm.ffi(inputs), (uint256, bytes));
    }
}
