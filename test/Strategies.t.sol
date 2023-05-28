// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {LibString} from "solady/utils/LibString.sol";

import {AggregatorsModule} from "src/modules/AggregatorsModule.sol";
import {FL} from "src/FL.sol";
import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {IPoolToken} from "src/interfaces/IPoolToken.sol";
import {Logger} from "src/Logger.sol";
import {MorphoModule} from "src/modules/MorphoModule.sol";
import {Morphous, Constants} from "src/Morphous.sol";
import {Neo, TokenUtils} from "src/Neo.sol";
import {TokenActionsModule} from "src/modules/TokenActionsModule.sol";

import {BaseTest} from "test/BaseTest.sol";
import {IMorphoLens} from "test/interfaces/IMorphoLens.sol";

/// @title StrategiesTest
/// @notice Test suite for strategies (leverage and deleverage)
contract StrategiesTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    ////////////////////////////////////////////////////////////////
    /// --- RECIPE 1: Deposit ETH / Supply stETH
    ///////////////////////////////////////////////////////////////

    function testStETHLeverage() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;
        uint256 _toFlashloan = 2e18;

        address _poolSupplyToken = 0x1982b2F5814301d4e9a8b0201555376e62F82428; // stETH Market
        address _poolBorrowToken = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // WETH Market

        _leverage(_poolSupplyToken, _poolBorrowToken, _proxy, _amount, _toFlashloan);

        (,, uint256 _totalSupplied) =
            IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolSupplyToken, _proxy);
        (,, uint256 _totalBorrowed) =
            IMorphoLens(_MORPHO_AAVE_LENS).getCurrentBorrowBalanceInOf(_poolBorrowToken, _proxy);

        assertEq(_totalSupplied, _amount + _toFlashloan);
        assertApproxEqAbs(_totalBorrowed, _toFlashloan, 1);

        (, bytes memory txData) = getQuote(_stETH, Constants._WETH, _totalSupplied, address(_proxy), "SELL");

        _deleverage(_poolSupplyToken, _poolBorrowToken, _proxy, _totalBorrowed, _totalSupplied, txData);

        (,, _totalSupplied) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolSupplyToken, _proxy);
        (,, _totalBorrowed) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentBorrowBalanceInOf(_poolBorrowToken, _proxy);

        assertEq(_totalSupplied, 0);
        assertEq(_totalBorrowed, 0);

        assertEq(TokenUtils._balanceInOf(Constants._WETH, _proxy), 0);

        assertLt(TokenUtils._balanceInOf(Constants._WETH, address(this)), _amount);
        assertGt(TokenUtils._balanceInOf(Constants._WETH, address(this)), _amount - 1e17);
    }

    function _leverage(
        address _poolSupplyToken,
        address _poolBorrowToken,
        address _proxy,
        uint256 _amount,
        uint256 _toFlashloan
    ) internal {
        address _market = Constants._MORPHO_AAVE;

        address _borrowToken = IPoolToken(_poolBorrowToken).UNDERLYING_ASSET_ADDRESS();

        /// Morphous calldata.
        bytes[] memory _calldata = new bytes[](5);

        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("withdrawWETH(uint256)", _toFlashloan));
        _calldata[1] =
            abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositSTETH(uint256)", _amount + _toFlashloan));
        _calldata[2] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature(
                "supply(address,address,address,uint256)", _market, _poolSupplyToken, _proxy, _amount + _toFlashloan
            )
        );
        _calldata[3] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("borrow(address,address,uint256)", _market, _poolBorrowToken, _toFlashloan)
        );
        _calldata[4] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _borrowToken, address(fl), _toFlashloan)
        );

        bytes memory _flashLoanData = abi.encode(_proxy, block.timestamp + 15, _calldata, new uint256[](5));

        // Flashloan functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _borrowToken;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _toFlashloan;

        bytes memory _proxyData = abi.encodeWithSignature(
            "executeFlashloan(address[],uint256[],bytes,bool)", _tokens, _amounts, _flashLoanData, false
        );

        proxy.execute{value: _amount}(address(neo), _proxyData);
    }

    function _deleverage(
        address _poolSupplyToken,
        address _poolBorrowToken,
        address _proxy,
        uint256 _totalBorrowed,
        uint256 _quote,
        bytes memory _txData
    ) internal {
        address _market = Constants._MORPHO_AAVE;

        address _supplyToken = IPoolToken(_poolSupplyToken).UNDERLYING_ASSET_ADDRESS();
        address _borrowToken = IPoolToken(_poolBorrowToken).UNDERLYING_ASSET_ADDRESS();

        /// Morphous calldata.
        bytes[] memory _calldata = new bytes[](4);

        _calldata[0] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature(
                "repay(address,address,address,uint256)", _market, _poolBorrowToken, _proxy, type(uint256).max
            )
        );
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolSupplyToken, type(uint256).max)
        );
        _calldata[2] = abi.encode(
            _AGGREGATORS_MODULE,
            abi.encodeWithSignature(
                "exchange(address,address,address,uint256,bytes)",
                ZERO_EX_ROUTER,
                _supplyToken,
                _borrowToken,
                _quote,
                _txData
            )
        );
        _calldata[3] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _borrowToken, address(fl), _totalBorrowed)
        );

        bytes memory _flashLoanData = abi.encode(_proxy, block.timestamp + 15, _calldata, new uint256[](4));

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _borrowToken;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _totalBorrowed;

        bytes memory _proxyData = abi.encodeWithSignature(
            "executeFlashloanWithReceiver(address[],address[],uint256[],bytes,address,bool)",
            _tokens,
            _tokens,
            _amounts,
            _flashLoanData,
            address(this),
            false
        );
        proxy.execute(address(neo), _proxyData);
    }
}
