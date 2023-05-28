// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

contract ModuleA {
    event Log(uint256 value);

    function A(uint256 value_) public {
        emit Log(value_);
    }
}

contract ModuleB {
    event Log(uint256 value);

    function B(uint256 value_) public {
        emit Log(value_);
    }
}
