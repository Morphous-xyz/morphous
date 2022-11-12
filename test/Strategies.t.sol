// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Neo} from "src/Neo.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Morpheus, Constants} from "src/Morpheus.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {BalancerFL} from "src/actions/flashloan/BalancerFL.sol";

contract StrategiesTest is Utils {
    Neo neo;
    IDSProxy proxy;
    Morpheus morpheous;
    BalancerFL balancerFL;

    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant _MAKER_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address internal constant _MORPHO_AAVE_LENS = 0x507fA343d0A90786d86C7cd885f5C49263A91FF4;
    address internal constant _MORPHO_COMPOUND_LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    function setUp() public {
        morpheous = new Morpheus();
        balancerFL = new BalancerFL(address(morpheous));
        neo = new Neo(address(morpheous), address(balancerFL));
        proxy = IDSProxy(MakerRegistry(_MAKER_REGISTRY).build());
    }

    function testInitialSetup() public {
        assertEq(proxy.owner(), address(this));
    }

    ////////////////////////////////////////////////////////////////
    /// --- RECIPE 1: Deposit sETH / Borrow WETH
    ///////////////////////////////////////////////////////////////

    function testStETHLeverage() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;
        uint256 _toFlashloan = 2e18;

        address _poolSupplyToken = 0x1982b2F5814301d4e9a8b0201555376e62F82428; // stETH Market
        address _poolBorrowToken = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // WETH Market

        _dealSteth(_amount);
        assertApproxEqAbs(ERC20(_stETH).balanceOf(address(this)), _amount, 1); // Wei Corner Case

        (uint256 quote, bytes memory txData) = getQuote(Constants._WETH, _stETH, _toFlashloan, address(_proxy), "SELL");
        _leverage(_poolSupplyToken, _poolBorrowToken, _proxy, _amount, _toFlashloan, quote, txData);

        (,, uint256 _totalSupplied) =
            IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolSupplyToken, _proxy);
        (,, uint256 _totalBorrowed) =
            IMorphoLens(_MORPHO_AAVE_LENS).getCurrentBorrowBalanceInOf(_poolBorrowToken, _proxy);

        assertApproxEqAbs(_totalSupplied, _amount + quote, 1);
        assertApproxEqAbs(_totalBorrowed, _toFlashloan, 1);

        (quote, txData) = getQuote(_stETH, Constants._WETH, _totalBorrowed, address(_proxy), "BUY");

        _deleverage(_poolSupplyToken, _poolBorrowToken, _proxy, _totalSupplied, _totalBorrowed, quote, txData);

        (,, _totalSupplied) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolSupplyToken, _proxy);
        (,, _totalBorrowed) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentBorrowBalanceInOf(_poolBorrowToken, _proxy);

        assertApproxEqAbs(_totalSupplied, 0, 1);
        assertApproxEqAbs(_totalBorrowed, 0, 1);
        assertApproxEqRel(ERC20(_stETH).balanceOf(address(this)), _amount, 2e16); // 2%
    }

    function _leverage(
        address _poolSupplyToken,
        address _poolBorrowToken,
        address _proxy,
        uint256 _amount,
        uint256 _toFlashloan,
        uint256 _quote,
        bytes memory _txData
    ) internal {
        address _market = Constants._MORPHO_AAVE;

        address _supplyToken = IPoolToken(_poolSupplyToken).UNDERLYING_ASSET_ADDRESS();
        address _borrowToken = IPoolToken(_poolBorrowToken).UNDERLYING_ASSET_ADDRESS();

        // Approve the proxy to spend the _supplyToken
        ERC20(_supplyToken).approve(_proxy, _amount);

        /// Morpheus calldata.
        bytes[] memory _calldata = new bytes[](5);
        _calldata[0] = abi.encodeWithSignature(
            "exchange(address,address,uint256,bytes)", _borrowToken, _supplyToken, _toFlashloan, _txData
        );
        _calldata[1] =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _supplyToken, address(this), _amount);
        _calldata[2] = abi.encodeWithSignature(
            "supply(address,address,address,uint256)", _market, _poolSupplyToken, _proxy, _amount + _quote
        );
        _calldata[3] =
            abi.encodeWithSignature("borrow(address,address,uint256)", _market, _poolBorrowToken, _toFlashloan);
        _calldata[4] = abi.encodeWithSignature(
            "transfer(address,address,uint256)", _borrowToken, address(balancerFL), _toFlashloan
        );

        bytes memory _flashLoanData = abi.encode(_proxy, block.timestamp + 15, _calldata);

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _borrowToken;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _toFlashloan;

        bytes memory _proxyData =
            abi.encodeWithSignature("executeFlashloan(address[],uint256[],bytes)", _tokens, _amounts, _flashLoanData);

        proxy.execute(address(neo), _proxyData);
    }

    function _deleverage(
        address _poolSupplyToken,
        address _poolBorrowToken,
        address _proxy,
        uint256 _totalSupplied,
        uint256 _totalBorrowed,
        uint256 _quote,
        bytes memory _txData
    ) internal {
        address _market = Constants._MORPHO_AAVE;

        address _supplyToken = IPoolToken(_poolSupplyToken).UNDERLYING_ASSET_ADDRESS();
        address _borrowToken = IPoolToken(_poolBorrowToken).UNDERLYING_ASSET_ADDRESS();

        /// Morpheus calldata.
        bytes[] memory _calldata = new bytes[](5);
        _calldata[0] = abi.encodeWithSignature(
            "repay(address,address,address,uint256)", _market, _poolBorrowToken, _proxy, _totalBorrowed
        );
        _calldata[1] =
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolSupplyToken, _totalSupplied);
        _calldata[2] = abi.encodeWithSignature(
            "exchange(address,address,uint256,bytes)", _supplyToken, _borrowToken, _quote, _txData
        );
        _calldata[3] = abi.encodeWithSignature(
            "transfer(address,address,uint256)", _borrowToken, address(balancerFL), _totalBorrowed
        );
        _calldata[4] = abi.encodeWithSignature(
            "transfer(address,address,uint256)", _supplyToken, address(this), _totalSupplied - _quote
        );

        bytes memory _flashLoanData = abi.encode(_proxy, block.timestamp + 15, _calldata);

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _borrowToken;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _totalBorrowed;

        bytes memory _proxyData =
            abi.encodeWithSignature("executeFlashloan(address[],uint256[],bytes)", _tokens, _amounts, _flashLoanData);

        proxy.execute(address(neo), _proxyData);
    }
}
