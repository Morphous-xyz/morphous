// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {Constants} from "src/Morphous.sol";

import {BaseTest} from "test/BaseTest.sol";

/// @title FlashloanTest
/// @notice Test suite for the Flashloan contract
contract FlashloanTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFlashLoanBalancer() public {
        // Flashloan _userData.
        address _neo = address(neo);
        address _proxy = address(proxy);
        uint256 _deadline = block.timestamp + 15;
        uint256 _amount = 1e18;

        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = abi.encode(
            Constants._TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _DAI, address(fl), _amount)
        );
        uint256[] memory _argPos = new uint256[](1);

        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata, _argPos);

        // Flashloan functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _DAI;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

        bytes memory _proxyData = abi.encodeWithSignature(
            "executeFlashloan(address[],uint256[],bytes,bool)", _tokens, _amounts, _flashLoanData, false
        );

        proxy.execute(_neo, _proxyData);
    }

    function testFlashLoanAave() public {
        // Flashloan _userData.
        address _neo = address(neo);
        address _proxy = address(proxy);
        uint256 _deadline = block.timestamp + 15;
        uint256 _amount = 1e18;

        uint256 _fee = _amount * 9 / 10000;
        deal(_DAI, _proxy, _fee);

        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = abi.encode(
            Constants._TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _DAI, address(fl), _amount + _fee)
        );

        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata, new uint256[](1));

        // Flashloan functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _DAI;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

        bytes memory _proxyData = abi.encodeWithSignature(
            "executeFlashloan(address[],uint256[],bytes,bool)", _tokens, _amounts, _flashLoanData, true
        );

        proxy.execute(_neo, _proxyData);
    }
}
