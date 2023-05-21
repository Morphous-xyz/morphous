// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Neo, TokenUtils} from "src/Neo.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ModMorphous, Constants} from "src/modular/ModMorphous.sol";
import {Zion} from "src/modular/Zion.sol";
import {AggregatorsModule} from "src/modular/modules/AggregatorsModule.sol";
import {TokenActionsModule} from "src/modular/modules/TokenActionsModule.sol";
import {MorphoModule} from "src/modular/modules/MorphoModule.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {FL} from "src/FL.sol";

contract ModStrategiesTest is Utils {
    Neo neo;
    IDSProxy proxy;
    ModMorphous morpheous;
    Zion zion;
    FL balancerFL;

    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant AUGUSTUS = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;
    address internal constant _MAKER_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address internal constant _MORPHO_AAVE_LENS = 0x507fA343d0A90786d86C7cd885f5C49263A91FF4;
    address internal constant _MORPHO_COMPOUND_LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    bytes32 internal constant _AGGREGATORS_MODULE = keccak256("AggregatorsModule");
    bytes32 internal constant _TOKEN_ACTIONS_MODULE = keccak256("TokenActionsModule");
    bytes32 internal constant _MORPHO_MODULE = keccak256("MorphoV2Module");

    function setUp() public {
        zion = new Zion();
        morpheous = new ModMorphous(zion);
        balancerFL = new FL(address(morpheous));
        neo = new Neo(address(morpheous), address(balancerFL));
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
            abi.encodeWithSignature(
                "transfer(address,address,uint256)", _borrowToken, address(balancerFL), _toFlashloan
            )
        );

        bytes memory _flashLoanData = abi.encode(_proxy, block.timestamp + 15, _calldata);

        // Flashlaon functions parameters.
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
                "exchange(address,address,address,uint256,bytes)", AUGUSTUS, _supplyToken, _borrowToken, _quote, _txData
            )
        );
        _calldata[3] = abi.encode(
            _TOKEN_ACTIONS_MODULE,
            abi.encodeWithSignature(
                "transfer(address,address,uint256)", _borrowToken, address(balancerFL), _totalBorrowed
            )
        );

        bytes memory _flashLoanData = abi.encode(_proxy, block.timestamp + 15, _calldata);

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
