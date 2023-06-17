// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";

import {FL} from "src/FL.sol";
import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Morphous, Constants} from "src/Morphous.sol";
import {Neo, TokenUtils} from "src/Neo.sol";

import {BaseTest} from "test/BaseTest.sol";
import {IMorphoLens} from "test/interfaces/IMorphoLens.sol";

/// @title AaveV3Test
/// @notice Test suite for the MorphoModule, all AAVE V3 functions
contract AaveV3Test is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    ////////////////////////////////////////////////////////////////
    /// --- MORPHO AAVE V3
    ///////////////////////////////////////////////////////////////

    function testMorphoSupply() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _token = Constants._WETH;
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,uint256,address,uint256)", _token, _amount, _proxy, 4)
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        uint256 _totalBalance = IMorphoLens(Constants._MORPHO_AAVE_V3).supplyBalance(_token, _proxy);
        assertApproxEqAbs(_totalBalance, _amount, 4);
    }

    function testMorphoWithdraw() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _token = Constants._WETH;
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](4);
        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,uint256,address,uint256)", _token, _amount, _proxy, 4)
        );
        _calldata[2] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature(
                "withdraw(address,uint256,address,address,uint256)", _token, _amount, _proxy, _proxy, 4
            )
        );
        _calldata[3] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("withdrawWETH(uint256)", _amount));

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata, new uint256[](4));

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        uint256 _totalBalance = IMorphoLens(Constants._MORPHO_AAVE_V3).supplyBalance(_token, _proxy);
        assertApproxEqAbs(_totalBalance, 0, 4);
        assertApproxEqAbs(_proxy.balance, _amount, 4);
    }

    function testMorphoSupplyBorrow() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _supplyToken = _DAI;
        address _token = Constants._WETH;
        uint256 _amount = 1e24;

        deal(_supplyToken, address(this), _amount);
        ERC20(_supplyToken).approve(_proxy, _amount);

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](3);
        _calldata[0] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _supplyToken, address(this), _amount)
        );
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supplyCollateral(address,uint256,address)", _supplyToken, _amount, _proxy)
        );
        _calldata[2] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("borrow(address,uint256,address,address,uint256)", _token, 1e18, _proxy, _proxy, 4)
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        uint256 _totalBorrowed = IMorphoLens(Constants._MORPHO_AAVE_V3).borrowBalance(_token, _proxy);
        uint256 _totalBalance = IMorphoLens(Constants._MORPHO_AAVE_V3).collateralBalance(_supplyToken, _proxy);

        assertApproxEqAbs(_totalBalance, _amount, 4);
        assertApproxEqAbs(_totalBorrowed, 1e18, 4);
        assertApproxEqAbs(ERC20(_token).balanceOf(_proxy), 1e18, 4);
    }
}
