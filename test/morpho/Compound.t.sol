// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Constants} from "src/Morphous.sol";
import {IMorphoLens} from "test/interfaces/IMorphoLens.sol";
import {BaseTest} from "test/BaseTest.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";

/// @title CompoundTest
/// @notice Test suite for the MorphoModule, all Compound functions (same as AAVE V2 but different markets)
contract CompoundTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testMorphoSupply() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_COMPOUND;
        address _poolToken = Constants._cETHER; // ETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, new uint256[](2));
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_COMPOUND_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertApproxEqRel(_totalBalance, _amount, 1e15); // 0.1%
    }

    function testMorphoWithdraw() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_COMPOUND;
        address _poolToken = Constants._cETHER; // WETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](4);

        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );
        _calldata[2] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );
        _calldata[3] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("withdrawWETH(uint256)", _amount));

        uint256[] memory _argPos = new uint256[](4);
        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, _argPos);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_COMPOUND_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertEq(_totalBalance, 0);
        assertApproxEqRel(_proxy.balance, _amount, 1e15); // 0.1%
    }
}
