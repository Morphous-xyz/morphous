// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {Neo} from "src/Neo.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Morpheus, Constants} from "src/Morpheus.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {BalancerFL} from "src/actions/flashloan/BalancerFL.sol";

interface MakerRegistry {
    function build() external returns (address proxy);
}

interface IPoolToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

interface IMorphoLens {
    function getCurrentSupplyBalanceInOf(address _token, address _user)
        external
        view
        returns (uint256, uint256, uint256);

    function getCurrentBorrowBalanceInOf(address _token, address _user)
        external
        view
        returns (uint256, uint256, uint256);
}

contract MorpheousTest is Test {
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
    /// --- FLASHLOAN
    ///////////////////////////////////////////////////////////////

    function testFlashLoanBalancer() public {
        // Flashloan _userData.
        address _neo = address(neo);
        address _proxy = address(proxy);
        uint256 _deadline = block.timestamp + 15;
        uint256 _amount = 1e18;

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encodeWithSignature("transfer(address,address,uint256)", _DAI, address(balancerFL), _amount);
        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata);

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _DAI;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

        bytes memory _proxyData =
            abi.encodeWithSignature("executeFlashloan(address[],uint256[],bytes)", _tokens, _amounts, _flashLoanData);

        proxy.execute(_neo, _proxyData);
    }

    ////////////////////////////////////////////////////////////////
    /// --- MORPHO WITHDRAW
    ///////////////////////////////////////////////////////////////

    function testMorphoSupply() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // WETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount);

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertEq(_totalBalance, _amount);
    }

    function testMorphoWithdraw() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // WETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](4);
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount);
        _calldata[2] =
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, _proxy, _amount);
        _calldata[3] = abi.encodeWithSignature("withdrawWETH(uint256)", _amount);

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertEq(_totalBalance, 0);
        assertEq(_proxy.balance, _amount);
    }

    function testFlashLoanSupplyWithdrawAave() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // WETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        address _token = IPoolToken(_poolToken).UNDERLYING_ASSET_ADDRESS(); // WETH

        bytes[] memory _calldata = new bytes[](3);
        _calldata[0] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount);
        _calldata[1] = abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, _amount);
        _calldata[2] =
            abi.encodeWithSignature("transfer(address,address,uint256)", _token, address(balancerFL), _amount);

        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata);

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _token;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

        bytes memory _proxyData =
            abi.encodeWithSignature("executeFlashloan(address[],uint256[],bytes)", _tokens, _amounts, _flashLoanData);

        proxy.execute(address(neo), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertEq(_totalBalance, 0);
        assertEq(ERC20(_token).balanceOf(_proxy), 0);
    }

    function testMorphoSupplyBorrow() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_AAVE;
        address _poolToken = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // WETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](3);
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount);
        _calldata[2] = abi.encodeWithSignature("borrow(address,address,uint256)", _market, _poolToken, _amount / 2);

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

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
        address _poolToken = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // WETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](4);
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount);
        _calldata[2] = abi.encodeWithSignature("borrow(address,address,uint256)", _market, _poolToken, _amount / 2);
        _calldata[3] =
            abi.encodeWithSignature("repay(address,address,address,uint256)", _market, _poolToken, _proxy, _amount / 2);

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalSupplied) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        (,, uint256 _totalBorrowed) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentBorrowBalanceInOf(_poolToken, _proxy);

        assertEq(_totalSupplied, _amount);
        assertEq(_totalBorrowed, 0);
        assertEq(ERC20(Constants._WETH).balanceOf(_proxy), 0);
    }

    ////////////////////////////////////////////////////////////////
    /// --- MORPHO COMPOUND
    ///////////////////////////////////////////////////////////////

    function testMorphoSupplyCompound() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_COMPOUND;
        address _poolToken = Constants._cETHER; // ETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount);

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_COMPOUND_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertApproxEqRel(_totalBalance, _amount, 1e15); // 0.01%
    }

    function testMorphoWithdrawCompound() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _market = Constants._MORPHO_COMPOUND;
        address _poolToken = Constants._cETHER; // WETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](4);
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount);
        _calldata[2] =
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, _proxy, _amount);
        _calldata[3] = abi.encodeWithSignature("withdrawWETH(uint256)", _amount);

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_COMPOUND_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertEq(_totalBalance, 0);
        assertApproxEqRel(_proxy.balance, _amount, 1e15); // 0.01%
    }
}
