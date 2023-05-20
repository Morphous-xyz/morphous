// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Logger} from "src/logger/Logger.sol";
import {Neo, TokenUtils} from "src/Neo.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Morphous, Constants} from "src/Morphous.sol";
import {LibString} from "solady/utils/LibString.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {FL} from "src/actions/flashloan/FL.sol";

contract MorpheousTest is Utils {
    Neo neo;
    IDSProxy proxy;
    Logger logger;
    Morphous morpheous;
    FL fl;

    address internal constant _LOGGER_PLACEHOLDER = 0x1234567890123456789012345678901234567890;

    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant ZERO_EX_ROUTER = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
    address public constant INCH_ROUTER = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address internal constant _MAKER_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address internal constant _MORPHO_AAVE_LENS = 0x507fA343d0A90786d86C7cd885f5C49263A91FF4;
    address internal constant _MORPHO_COMPOUND_LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    function setUp() public {
        logger = new Logger();

        bytes memory _morphousByteCode = bytes(
            LibString.replace(
                string(abi.encodePacked(type(Morphous).creationCode)),
                string(abi.encodePacked(_LOGGER_PLACEHOLDER)),
                string(abi.encodePacked(address(logger)))
            )
        );

        // Deploy the contract with the correct constant address.
        morpheous = Morphous(payable(deployBytecode(_morphousByteCode, "")));

        fl = new FL(address(morpheous));
        neo = new Neo(address(morpheous), address(fl));
        proxy = IDSProxy(IMakerRegistry(_MAKER_REGISTRY).build());
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

        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = abi.encodeWithSignature("transfer(address,address,uint256)", _DAI, address(fl), _amount);
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
        _calldata[0] = abi.encodeWithSignature("transfer(address,address,uint256)", _DAI, address(fl), _amount + _fee);

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

    ////////////////////////////////////////////////////////////////
    /// --- MORPHO AAVE
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

        uint256[] memory _argPos = new uint256[](2);

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, _argPos);
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertApproxEqAbs(_totalBalance, _amount, 1);
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

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, new uint256[](4));

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertApproxEqAbs(_totalBalance, 0, 1);
        assertApproxEqAbs(_proxy.balance, _amount, 1);
    }

    function testMorphoWithdrawWithReceiver() public {
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
        _calldata[2] =
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, _proxy, _amount);

        uint256[] memory _argPos = new uint256[](3);
        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, _argPos);

        address[] memory tokens = new address[](1);
        tokens[0] = Constants._WETH;

        bytes memory _neoData =
            abi.encodeWithSignature("executeWithReceiver(address[],bytes,address)", tokens, _proxyData, address(this));

        proxy.execute{value: _amount}(address(neo), _neoData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertApproxEqAbs(_totalBalance, 0, 1);
        assertEq(TokenUtils._balanceInOf(Constants._WETH, _proxy), 0);
        assertEq(TokenUtils._balanceInOf(Constants._WETH, address(this)), _amount);
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
        _calldata[2] = abi.encodeWithSignature("transfer(address,address,uint256)", _token, address(fl), _amount);

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
        address _poolToken = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // WETH Market
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        address _token = IPoolToken(_poolToken).UNDERLYING_ASSET_ADDRESS(); // WETH

        deal(_token, address(this), _amount);
        ERC20(_token).approve(_proxy, _amount);

        bytes[] memory _calldata = new bytes[](4);
        _calldata[0] = abi.encodeWithSignature("transferFrom(address,address,uint256)", _token, address(this), _amount);
        _calldata[1] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount * 2);
        _calldata[2] =
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, type(uint256).max);
        _calldata[3] = abi.encodeWithSignature("transfer(address,address,uint256)", _token, address(fl), _amount);

        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata, new uint256[](4));

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _token;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;

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

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertApproxEqAbs(_totalBalance, 0, 1);
        assertEq(TokenUtils._balanceInOf(_token, _proxy), 0);
        assertEq(TokenUtils._balanceInOf(_token, address(this)), _amount);
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

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, new uint256[](3));
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

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, new uint256[](4));
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalSupplied) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        (,, uint256 _totalBorrowed) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentBorrowBalanceInOf(_poolToken, _proxy);

        assertEq(_totalSupplied, _amount);
        assertApproxEqAbs(_totalBorrowed, 0, 1);
        assertApproxEqAbs(ERC20(Constants._WETH).balanceOf(_proxy), 0, 1);
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

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, new uint256[](2));
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_COMPOUND_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertApproxEqRel(_totalBalance, _amount, 1e15); // 0.1%
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

        uint256[] memory _argPos = new uint256[](4);
        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, _argPos);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_COMPOUND_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertEq(_totalBalance, 0);
        assertApproxEqRel(_proxy.balance, _amount, 1e15); // 0.1%
    }

    ////////////////////////////////////////////////////////////////
    /// --- AGGREGATORS
    ///////////////////////////////////////////////////////////////

    function testGetQuote() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, address(_proxy), "SELL");
        assertGt(quote, 0);
        assertGt(txData.length, 0);
    }

    function testSwap() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, address(_proxy), "SELL");

        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = abi.encodeWithSignature(
            "exchange(address,address,address,uint256,bytes)", ZERO_EX_ROUTER, Constants._ETH, _DAI, _amount, txData
        );

        uint256[] memory _argPos = new uint256[](1);

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, _argPos);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        assertApproxEqRel(ERC20(_DAI).balanceOf(_proxy), quote, 1e16); // 1%
    }

    function testSwapAndSupply() public {
        uint256 _amount = 1e18;

        address _market = Constants._MORPHO_AAVE;
        address _poolToken = 0x028171bCA77440897B824Ca71D1c56caC55b68A3; // DAI Market

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, address(proxy), "SELL");

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encodeWithSignature(
            "exchange(address,address,address,uint256,bytes)", ZERO_EX_ROUTER, Constants._ETH, _DAI, _amount, txData
        );
        _calldata[1] =
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, proxy, quote);

        uint256[] memory _argPos = new uint256[](2);
        _argPos[0] = 0;
        _argPos[1] = 4 + 96; // 4 for sig + 4th arguments starts at 96 bytes. (3 * 32 bytes)

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, _argPos);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalSupplied) =
            IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, address(proxy));

        /// Total supplied should be greater or equal than the quote.
        assertGe(_totalSupplied, quote);
    }

    /// @notice Helper function to deploy a contract from bytecode.
    function deployBytecode(bytes memory bytecode, bytes memory args) private returns (address deployed) {
        bytecode = abi.encodePacked(bytecode, args);
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(deployed != address(0), "DEPLOYMENT_FAILED");
    }
}
