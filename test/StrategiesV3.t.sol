// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/BaseTest.sol";
import {FL} from "src/FL.sol";
import {Logger} from "src/Logger.sol";
import {Neo, TokenUtils} from "src/Neo.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ILido} from "src/interfaces/ILido.sol";
import {Morphous, Constants} from "src/Morphous.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {IPoolToken} from "src/interfaces/IPoolToken.sol";
import {MorphoModule} from "src/modules/MorphoModule.sol";
import {AggregatorsModule} from "src/modules/AggregatorsModule.sol";
import {TokenActionsModule} from "src/modules/TokenActionsModule.sol";
import {IMorphoLens} from "test/interfaces/IMorphoLens.sol";

/// @title StrategiesTest
/// @notice Test suite for strategies (leverage and deleverage)
contract StrategiesV3Test is BaseTest {
    function setUp() public override {
        uint256 _id = vm.createFork(vm.envString("RPC_URL_MAINNET"), 17174536); // Block number with Supply Cap not reached for wsETH.
        vm.selectFork(_id);

        super.setUp();
    }

    ////////////////////////////////////////////////////////////////
    /// --- RECIPE 1: Deposit ETH / Supply stETH
    ///////////////////////////////////////////////////////////////

    function testStETHLeverageV3() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;
        uint256 _toFlashloan = 2e18;

        address _supplyToken = Constants._wstETH; // stETH Market
        address _borrowToken = Constants._WETH; // WETH Market

        uint256 _expectedSupplied = ILido(_supplyToken).getWstETHByStETH(_amount + _toFlashloan);

        _leverage(_supplyToken, _borrowToken, _proxy, _amount, _toFlashloan);

        uint256 _totalSupplied = IMorphoLens(Constants._MORPHO_AAVE_V3).collateralBalance(_supplyToken, _proxy);
        uint256 _totalBorrowed = IMorphoLens(Constants._MORPHO_AAVE_V3).borrowBalance(_borrowToken, _proxy);

        assertApproxEqAbs(_totalBorrowed, _toFlashloan, 1);
        assertApproxEqAbs(_totalSupplied, _expectedSupplied, 1);

        (, bytes memory txData) = getQuote(_supplyToken, _borrowToken, _totalSupplied, "SELL");

        _deleverage(_supplyToken, _borrowToken, _proxy, _totalBorrowed, _totalSupplied, txData);

        _totalSupplied = IMorphoLens(Constants._MORPHO_AAVE_V3).collateralBalance(_supplyToken, _proxy);
        _totalBorrowed = IMorphoLens(Constants._MORPHO_AAVE_V3).borrowBalance(_borrowToken, _proxy);

        assertEq(_totalSupplied, 0);
        assertEq(_totalBorrowed, 0);

        assertEq(TokenUtils._balanceInOf(Constants._WETH, _proxy), 0);
        assertLt(TokenUtils._balanceInOf(Constants._WETH, address(this)), _amount);
        assertGt(TokenUtils._balanceInOf(Constants._WETH, address(this)), _amount - 1e17);
    }

    function _leverage(
        address _supplyToken,
        address _borrowToken,
        address _proxy,
        uint256 _amount,
        uint256 _toFlashloan
    ) internal {
        /// Morphous calldata.
        bytes[] memory _calldata = new bytes[](6);

        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("withdrawWETH(uint256)", _toFlashloan));
        _calldata[1] =
            abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositSTETH(uint256)", _amount + _toFlashloan));

        _calldata[2] =
            abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("wrapstETH(uint256)", _amount + _toFlashloan));

        _calldata[3] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature(
                "supplyCollateral(address,uint256,address)", _supplyToken, _amount + _toFlashloan, _proxy
            )
        );
        _calldata[4] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature(
                "borrow(address,uint256,address,address,uint256)", _borrowToken, _toFlashloan, _proxy, _proxy, 4
            )
        );
        _calldata[5] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _borrowToken, address(fl), _toFlashloan)
        );

        uint256[] memory _argPos = new uint256[](6);
        _argPos[3] = 4 + 32;

        bytes memory _flashLoanData = abi.encode(_proxy, block.timestamp + 15, _calldata, _argPos);

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
        address _supplyToken,
        address _borrowToken,
        address _proxy,
        uint256 _totalBorrowed,
        uint256 _quote,
        bytes memory _txData
    ) internal {
        /// Morphous calldata.
        bytes[] memory _calldata = new bytes[](4);

        _calldata[0] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("repay(address,uint256,address)", _borrowToken, type(uint256).max, _proxy)
        );
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature(
                "withdrawCollateral(address,uint256,address,address)", _supplyToken, type(uint256).max, _proxy, _proxy
            )
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
