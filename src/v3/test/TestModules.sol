// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/console.sol";

contract ModuleA {
    event Log(uint256 value);

    function testA(uint256 value_) public {
        emit Log(value_);
    }
}

contract ModuleB {
    event Log(uint256 value);

    function testB(uint256 value_) public {
        emit Log(value_);
    }
}
