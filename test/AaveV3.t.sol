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

contract AaveV3Test is Utils {
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
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] = abi.encodeWithSignature("supply(address,uint256,address,uint256)", _token, _amount, _proxy, 4);

        uint256[] memory _argPos = new uint256[](2);

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, _argPos);
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
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] = abi.encodeWithSignature("supply(address,uint256,address,uint256)", _token, _amount, _proxy, 4);
        _calldata[2] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,address,uint256)", _token, _amount, _proxy, _proxy, 4
        );
        _calldata[3] = abi.encodeWithSignature("withdrawWETH(uint256)", _amount);

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, new uint256[](4));

        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        uint256 _totalBalance = IMorphoLens(Constants._MORPHO_AAVE_V3).supplyBalance(_token, _proxy);
        assertApproxEqAbs(_totalBalance, 0, 4);
        assertApproxEqAbs(_proxy.balance, _amount, 4);
    }

    function testMorphoSupplyBorrow() public {
        address _proxy = address(proxy);
        // Supply _userData.
        address _token = Constants._WETH;
        uint256 _amount = 10e18;

        // Flashloan _userData.
        uint256 _deadline = block.timestamp + 15;

        bytes[] memory _calldata = new bytes[](3);
        _calldata[0] = abi.encodeWithSignature("depositWETH(uint256)", _amount);
        _calldata[1] = abi.encodeWithSignature("supplyCollateral(address,uint256,address)", _token, _amount, _proxy);
        _calldata[2] = abi.encodeWithSignature(
            "borrow(address,uint256,address,address,uint256)", _token, _amount / 2, _proxy, _proxy, 4
        );

        uint256[] memory _argPos = new uint256[](3);

        bytes memory _proxyData =
            abi.encodeWithSignature("multicall(uint256,bytes[],uint256[])", _deadline, _calldata, _argPos);
        proxy.execute{value: _amount}(address(morpheous), _proxyData);

        uint256 _totalBorrowed = IMorphoLens(Constants._MORPHO_AAVE_V3).borrowBalance(_token, _proxy);
        uint256 _totalBalance = IMorphoLens(Constants._MORPHO_AAVE_V3).collateralBalance(_token, _proxy);

        assertApproxEqAbs(_totalBalance, _amount, 4);
        assertApproxEqAbs(_totalBorrowed, _amount / 2, 4);
        assertApproxEqAbs(ERC20(_token).balanceOf(_proxy), _amount / 2, 4);
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
