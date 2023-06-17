// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Constants} from "src/Morphous.sol";

import {IMorphoLens} from "test/interfaces/IMorphoLens.sol";
import {BaseTest} from "test/BaseTest.sol";

/// @title AggregatorsTest
/// @notice Test suite for the AggregatorsModule contract
contract AggregatorsTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testGetQuote() public {
        uint256 _amount = 1e18;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, "SELL");
        assertGt(quote, 0);
        assertGt(txData.length, 0);
    }

    function testSwap() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, "SELL");

        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = abi.encode(
            _AGGREGATORS_MODULE,
            abi.encodeWithSignature(
                "exchange(address,address,address,uint256,bytes)", ZERO_EX_ROUTER, Constants._ETH, _DAI, _amount, txData
            )
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        assertApproxEqRel(ERC20(_DAI).balanceOf(_proxy), quote, 1e16); // 1%
    }

    function testSwapAndSupply() public {
        uint256 _amount = 1e18;

        address _market = Constants._MORPHO_AAVE;
        address _poolToken = 0x028171bCA77440897B824Ca71D1c56caC55b68A3; // DAI Market

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, "SELL");

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encode(
            _AGGREGATORS_MODULE,
            abi.encodeWithSignature(
                "exchange(address,address,address,uint256,bytes)", ZERO_EX_ROUTER, Constants._ETH, _DAI, _amount, txData
            )
        );
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, proxy, quote)
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalSupplied) =
            IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, address(proxy));

        /// Total supplied should be greater or equal than the quote.
        assertGe(_totalSupplied, quote);
    }
}
