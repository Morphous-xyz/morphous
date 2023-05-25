// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Constants} from "src/Morphous.sol";

import {BaseTest} from "test/BaseTest.sol";

import {ModuleA, ModuleB} from "test/utils/TestModules.sol";

/// @title MorphousTest
/// @notice Test suite for the Morphous contract (Morphous Multicall + Zion registry)
contract MorphousTest is BaseTest {
    // For test modules
    event Log(uint256);

    function setUp() public override {
        super.setUp();
    }

    ////////////////////////////////////////////////////////////////
    /// --- ZION
    ///////////////////////////////////////////////////////////////

    function testOwnerSetModule() public {
        bytes1 identifier = 0x10;
        morpheous.setModule(identifier, address(0xAbA));
        assertEq(morpheous.getModule(identifier), address(0xAbA));
    }

    function testNonOwnerSetModule(address owner) public {
        vm.assume(owner != address(this));
        morpheous.transferOwnership(owner);

        vm.expectRevert("UNAUTHORIZED");
        morpheous.setModule(0x10, address(0xAbA));
    }

    function testOwnerOverwriteModule() public {
        bytes1 identifier = 0x10;
        morpheous.setModule(identifier, address(0xAbA));
        assertEq(morpheous.getModule(identifier), address(0xAbA));

        morpheous.setModule(identifier, address(0xCACA));
        assertEq(morpheous.getModule(identifier), address(0xCACA));
    }

    function testGetUnsetModule() public {
        assertEq(morpheous.getModule(0x10), address(0));
    }

    ////////////////////////////////////////////////////////////////
    /// --- MORPHOUS
    ///////////////////////////////////////////////////////////////

    function testMulticall() public {
        // Deploy both test modules
        ModuleA moduleA = new ModuleA();
        ModuleB moduleB = new ModuleB();

        // Set modules in Zion
        bytes1 identifierA = 0x10;
        bytes1 identifierB = 0x11;

        morpheous.setModule(identifierA, address(moduleA));
        morpheous.setModule(identifierB, address(moduleB));

        // Encode call data
        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encode(identifierA, abi.encodeWithSignature("A(uint256)", 1));
        _calldata[1] = abi.encode(identifierB, abi.encodeWithSignature("B(uint256)", 2));

        uint256[] memory _argPos = new uint256[](2);

        // Execute multicall via DsProxy (using a delegatecall)
        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", block.timestamp + 15, _calldata, _argPos);

        // Check that the modules were called correctly
        vm.expectEmit(true, true, true, true);
        emit Log(1);
        emit Log(2);

        proxy.execute(address(morpheous), _proxyData);
    }

    function testVersion() public {
        assertEq(morpheous.version(), "2.0.0");
    }
}
