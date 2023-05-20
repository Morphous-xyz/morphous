// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Neo, TokenUtils} from "src/Neo.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Constants} from "src/libraries/Constants.sol";
import {Zion} from "src/Zion.sol";
import {Morphous} from "src/Morphous.sol";
import {AggregatorsModule} from "src/modules/AggregatorsModule.sol";
import {TokenActionsModule} from "src/modules/TokenActionsModule.sol";
import {MorphoModule} from "src/modules/MorphoModule.sol";

import {ModuleA, ModuleB} from "src/test/TestModules.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {FL} from "src/FL.sol";

contract MorpheousTest is Utils {
    Neo neo;
    IDSProxy proxy;
    Morphous morpheous;
    Zion zion;
    FL fl;

    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant AUGUSTUS = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;
    address public constant INCH_ROUTER = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address internal constant _MAKER_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address internal constant _MORPHO_AAVE_LENS = 0x507fA343d0A90786d86C7cd885f5C49263A91FF4;
    address internal constant _MORPHO_COMPOUND_LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    bytes32 internal constant _AGGREGATORS_MODULE = keccak256("AggregatorsModule");
    bytes32 internal constant _TOKEN_ACTIONS_MODULE = keccak256("TokenActionsModule");
    bytes32 internal constant _MORPHO_MODULE = keccak256("MorphoV2Module");

    // For test modules
    event Log(uint256 value);

    function setUp() public {
        zion = new Zion();
        morpheous = new Morphous(zion);
        fl = new FL(address(morpheous));
        neo = new Neo(address(morpheous), address(fl));
        proxy = IDSProxy(IMakerRegistry(_MAKER_REGISTRY).build());

        // Modules
        AggregatorsModule aggregatorsModule = new AggregatorsModule();
        TokenActionsModule tokenActionsModule = new TokenActionsModule();
        MorphoModule morphoModule = new MorphoModule();

        // Add modules to Zion
        zion.setModule(_AGGREGATORS_MODULE, address(aggregatorsModule));
        zion.setModule(_TOKEN_ACTIONS_MODULE, address(tokenActionsModule));
        zion.setModule(_MORPHO_MODULE, address(morphoModule));
    }

    function testInitialSetup() public {
        assertEq(proxy.owner(), address(this));
    }

    ////////////////////////////////////////////////////////////////
    /// --- ZION
    ///////////////////////////////////////////////////////////////

    function testOwnerSetModule() public {
        bytes32 identifier = keccak256("Test");
        zion.setModule(identifier, address(0xAbA));
        assertEq(zion.getModule(identifier), address(0xAbA));
    }

    function testNonOwnerSetModule(address owner) public {
        vm.assume(owner != address(this));
        zion.transferOwnership(owner);

        vm.expectRevert("UNAUTHORIZED");
        zion.setModule(keccak256(""), address(0xAbA));
    }

    function testOwnerCannotOverwriteModule() public {
        bytes32 identifier = keccak256("Test");
        zion.setModule(identifier, address(0xAbA));
        assertEq(zion.getModule(identifier), address(0xAbA));

        vm.expectRevert("Module already set");
        zion.setModule(identifier, address(0xCACA));
    }

    function testGetUnsetModule() public {
        assertEq(zion.getModule(keccak256("")), address(0));
    }

    ////////////////////////////////////////////////////////////////
    /// --- MODULAR MORPHOUS
    ///////////////////////////////////////////////////////////////

    function testMulticall() public {
        // Deploy both test modules
        ModuleA moduleA = new ModuleA();
        ModuleB moduleB = new ModuleB();

        // Set modules in Zion
        bytes32 identifierA = keccak256("ModuleA");
        bytes32 identifierB = keccak256("ModuleB");

        zion.setModule(identifierA, address(moduleA));
        zion.setModule(identifierB, address(moduleB));

        // Encode call data
        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encode(identifierA, abi.encodeWithSignature("A(uint256)", 1));
        _calldata[1] = abi.encode(identifierB, abi.encodeWithSignature("B(uint256)", 2));

        // Execute multicall via DsProxy (using a delegatecall)
        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", block.timestamp + 15, _calldata);

        // Check that the modules were called correctly
        vm.expectEmit(true, true, true, true);
        emit Log(1);
        emit Log(2);
        proxy.execute(address(morpheous), _proxyData);
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
        _calldata[0] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _DAI, address(fl), _amount)
        );
        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata);

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

        bytes[] memory _calldata = new bytes[](2);
        _calldata[0] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature("transfer(address,address,uint256)", _DAI, address(fl), _amount + _fee)
        );
        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata);

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
        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
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

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

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

        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );
        _calldata[2] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("withdraw(address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

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

        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata);

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

        bytes memory _flashLoanData = abi.encode(_proxy, _deadline, _calldata);

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

        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );
        _calldata[2] = abi.encode(
            _MORPHO_MODULE, abi.encodeWithSignature("borrow(address,address,uint256)", _market, _poolToken, _amount / 2)
        );

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

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
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

        _calldata[0] = abi.encode(_TOKEN_ACTIONS_MODULE, abi.encodeWithSignature("depositWETH(uint256)", _amount));
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, _amount)
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);
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

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalBalance) = IMorphoLens(_MORPHO_COMPOUND_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);

        assertEq(_totalBalance, 0);
        assertApproxEqRel(_proxy.balance, _amount, 1e15); // 0.1%
    }

    ////////////////////////////////////////////////////////////////
    /// --- PARASWAP
    ///////////////////////////////////////////////////////////////

    function testParaswapGetQuote() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, address(_proxy), "SELL");
        assertGt(quote, 0);
        assertGt(txData.length, 0);
    }

    function testParaswapSwap() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, address(_proxy), "SELL");

        bytes[] memory _calldata = new bytes[](1);

        _calldata[0] = abi.encode(
            _AGGREGATORS_MODULE,
            abi.encodeWithSignature(
                "exchange(address,address,address,uint256,bytes)", AUGUSTUS, Constants._ETH, _DAI, _amount, txData
            )
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        assertApproxEqRel(ERC20(_DAI).balanceOf(_proxy), quote, 1e16); // 1%
    }

    function testParaswapSwapAndSupply() public {
        address _proxy = address(proxy);
        uint256 _amount = 1e18;

        address _market = Constants._MORPHO_AAVE;
        address _poolToken = 0x028171bCA77440897B824Ca71D1c56caC55b68A3; // DAI Market

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;
        (uint256 quote, bytes memory txData) = getQuote(Constants._ETH, _DAI, _amount, address(_proxy), "SELL");

        bytes[] memory _calldata = new bytes[](2);

        _calldata[0] = abi.encode(
            _AGGREGATORS_MODULE,
            abi.encodeWithSignature(
                "exchange(address,address,address,uint256,bytes)", AUGUSTUS, Constants._ETH, _DAI, _amount, txData
            )
        );
        _calldata[1] = abi.encode(
            _MORPHO_MODULE,
            abi.encodeWithSignature("supply(address,address,address,uint256)", _market, _poolToken, _proxy, quote)
        );

        bytes memory _proxyData = abi.encodeWithSignature("multicall(uint256,bytes[])", _deadline, _calldata);

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        (,, uint256 _totalSupplied) = IMorphoLens(_MORPHO_AAVE_LENS).getCurrentSupplyBalanceInOf(_poolToken, _proxy);
        assertApproxEqAbs(_totalSupplied, quote, 1);
    }
}
