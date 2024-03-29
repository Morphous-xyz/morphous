// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Constants} from "src/Morphous.sol";
import {BaseTest} from "test/BaseTest.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {IPoolToken} from "src/interfaces/IPoolToken.sol";
import {IMorphoLens} from "test/interfaces/IMorphoLens.sol";

/// @title AaveV2Test
/// @notice Test suite for the MorphoModule, all AAVE V2 functions
contract AaveV2Test is BaseTest {
    address internal constant _WETH_MARKET = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;

    function setUp() public override {
        super.setUp();
    }

    function testMorphoSupply() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = _WETH_MARKET;
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
        proxy.execute{value: _amount}(address(morphous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertApproxEqAbs(_totalBalance, _amount, 1);
    }

    function testMorphoWithdraw() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = _WETH_MARKET;
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

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata, new uint256[](4));

        proxy.execute{value: _amount}(address(morphous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertApproxEqAbs(_totalBalance, 0, 1);
        assertApproxEqAbs(_proxy.balance, _amount, 1);
    }

    function testMorphoWithdrawWithReceiver() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = _WETH_MARKET;
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
        _calldata[3] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature(
                "transfer(address,address,uint256)", Constants._WETH, address(this), type(uint256).max
            )
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

        proxy.execute{value: _amount}(address(morphous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertApproxEqAbs(_totalBalance, 0, 1);
        assertEq(TokenUtils._balanceInOf(Constants._WETH, _proxy), 0);
        assertEq(TokenUtils._balanceInOf(Constants._WETH, address(this)), _amount);
    }

    function testFlashLoanSupplyWithdrawAave() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = _WETH_MARKET;
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        address _token = IPoolToken(_poolToken).UNDERLYING_ASSET_ADDRESS(); // WETH

        bytes[] memory _calldata = new bytes[](3);
        _calldata[0] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );
        _calldata[2] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _token, address(fl), _amount)
        );

        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata, new uint256[](3));

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _token;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

        bytes memory _proxyData = abi.encodeWithSignature(
            "executeFlashloan(address[],uint256[],bytes,bool)", _tokens, _amounts, _flashLoanData, false
        );

        proxy.execute(address(neo), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertApproxEqAbs(_totalBalance, 0, 1);
        assertApproxEqAbs(ERC20(_token).balanceOf(_proxy), 0, 1);
    }

    function testFlashLoanSupplyWithdrawAaveWithReceiver() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = _WETH_MARKET;
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        address _token = IPoolToken(_poolToken).UNDERLYING_ASSET_ADDRESS(); // WETH

        deal(_token, address(this), _amount);
        ERC20(_token).approve(_proxy, _amount);

        bytes[] memory _calldata = new bytes[](5);

        _calldata[0] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _token, address(this), _amount)
        );
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount * 2)
        );
        _calldata[2] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, _proxy, type(uint256).max)
        );
        _calldata[3] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _token, address(fl), _amount)
        );
        _calldata[4] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _token, address(this), type(uint256).max)
        );

        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata, new uint256[](4));

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _token;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

        bytes memory _proxyData = abi.encodeWithSignature(
            "executeFlashloan(address[],uint256[],bytes,bool)", _tokens, _amounts, _flashLoanData, false
        );

        proxy.execute(address(neo), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertApproxEqAbs(_totalBalance, 0, 1);
        assertEq(TokenUtils._balanceInOf(_token, _proxy), 0);
        assertEq(TokenUtils._balanceInOf(_token, address(this)), _amount);
    }

    function testMorphoSupplyBorrow() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = _WETH_MARKET;
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](3);

        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );
        _calldata[2] = abi.encode(
            _MORPHO_MODULE, abi.encodeWithSignature("borrow(address,address,uint256)", _market, _poolToken, _amount / 2)
        );

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata, new uint256[](3));
        proxy.execute{value: _amount}(address(morphous), _proxyData);

        (,, uint256 _totalSupplied) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        (,, uint256 _totalBorrowed) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentBorrowBalanceInOf(_poolToken, _proxy);

        assertEq(_totalSupplied, _amount);
        assertEq(_totalBorrowed, _amount / 2);
        assertEq(ERC20(Constants._WETH).balanceOf(_proxy), _amount / 2);
    }

    function testMorphoSupplyBorrowRepay() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = _WETH_MARKET;
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
            _MORPHO_MODULE, abi.encodeWithSignature("borrow(address,address,uint256)", _market, _poolToken, _amount / 2)
        );
        _calldata[3] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("repay(address,address,address,uint256)", _market, _poolToken, _proxy, _amount / 2)
        );

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata, new uint256[](4));
        proxy.execute{value: _amount}(address(morphous), _proxyData);

        (,, uint256 _totalSupplied) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        (,, uint256 _totalBorrowed) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentBorrowBalanceInOf(_poolToken, _proxy);

        assertEq(_totalSupplied, _amount);
        assertApproxEqAbs(_totalBorrowed, 0, 1);
        assertApproxEqAbs(ERC20(Constants._WETH).balanceOf(_proxy), 0, 1);
    }
}
